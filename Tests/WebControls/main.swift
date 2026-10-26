// swiftformat:disable wrapMultilineStatementBraces
import Cocoa
import WebKit

NSApplication.shared.setActivationPolicy(.prohibited)
for key in ["previewFontSize", "previewWrap", "previewAppearance"] {
	UserDefaults.standard.removeObject(forKey: key)
}

let directory = URL(fileURLWithPath: CommandLine.arguments[1])
var failures = 0
func check(_ value: Bool, _ message: String) {
	if value { print("PASS: \(message)") } else { print("FAIL: \(message)"); failures += 1 }
}

func wait(_ condition: () -> Bool, seconds: TimeInterval = 15) -> Bool {
	let deadline = Date().addingTimeInterval(seconds)
	while !condition(),
	      Date() < deadline {
		RunLoop.current.run(until: Date().addingTimeInterval(0.02))
	}
	return condition()
}

func javascript(_ source: String, in controller: WebPreviewVC) -> Any? {
	var done = false
	var result: Any?
	controller.webView.evaluateJavaScript(source) { value, error in
		if let error = error { print("JavaScript: \(error)") }
		result = value; done = true
	}
	_ = wait { done }
	return result
}

func attach(_ controller: WebPreviewVC) -> NSWindow {
	let window = NSWindow(
		contentRect: NSRect(x: -100_000, y: -100_000, width: 900, height: 650),
		styleMask: [.titled],
		backing: .buffered,
		defer: false
	)
	window.isReleasedWhenClosed = false
	window.contentViewController = controller
	return window
}

func screenshot(_ controller: WebPreviewVC, name: String) {
	var done = false
	controller.webView.takeSnapshot(with: nil) { image, _ in
		defer { done = true }
		if let data = image?.tiffRepresentation,
		   let rep = NSBitmapImageRep(data: data),
		   let png = rep.representation(using: .png, properties: [:]) {
			try? png.write(to: directory.appendingPathComponent(name + ".png"))
		}
	}
	check(wait { done }, "Offscreen snapshot completed")
}

let controller = WebPreviewVC(
	html: "<h1>Heading</h1><h2>Details</h2><pre>long line</pre>",
	source: "original source"
)
let window = attach(controller)
check(
	wait { javascript("window.glanceReady === true", in: controller) as? Bool == true },
	"Web controls document ready"
)
check(
	javascript("document.querySelectorAll('#glance-toc a').length", in: controller) as? Int == 2,
	"Contents links generated"
)
func allViews(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(allViews) }
let buttons = allViews(controller.view).compactMap { $0 as? NSButton }
check(
	["Contents", "Next", "Copy", "A−", "A+", "Wrap"]
		.allSatisfy { title in buttons.contains { $0.title == title } },
	"All native controls present"
)
buttons.first { $0.title == "Contents" }?.performClick(nil)
check(
	wait {
		javascript("document.body.classList.contains('contents')", in: controller) as? Bool == true
	},
	"Contents toggles the actual web view"
)
let oldFont = (javascript(
	"parseFloat(getComputedStyle(document.body).fontSize)",
	in: controller
) as? NSNumber)?.doubleValue ?? 0
buttons.first { $0.title == "A+" }?.performClick(nil)
let grew = wait {
	let current = (javascript(
		"parseFloat(getComputedStyle(document.body).fontSize)",
		in: controller
	) as? NSNumber)?.doubleValue
	return current == oldFont + 1
}

check(grew, "Font control changes rendered text")
let oldWrap = javascript("document.body.classList.contains('wrap')", in: controller) as? Bool
buttons.first { $0.title == "Wrap" }?.performClick(nil)
check(
	wait {
		(javascript("document.body.classList.contains('wrap')", in: controller) as? Bool) !=
			oldWrap
	},
	"Wrap changes rendered document"
)
screenshot(controller, name: "web-controls")
if let native = controller.view.bitmapImageRepForCachingDisplay(in: controller.view.bounds) {
	controller.view.cacheDisplay(in: controller.view.bounds, to: native)
	if let png = native.representation(using: .png, properties: [:]) {
		try png.write(to: directory.appendingPathComponent("web-controls-native.png"))
	}
}

window.close()

print("Failures: \(failures)")
exit(failures == 0 ? 0 : 1)
