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

let file = directory.appendingPathComponent("live.html")
let longHTML = "<h1>Live</h1>" + (0 ..< 200)
	.map { "<p>Paragraph \($0) for scroll verification.</p>" }.joined()
try longHTML.write(to: file, atomically: true, encoding: .utf8)
let controller = WebPreviewVC(html: longHTML)
let window = attach(controller)
check(
	wait { javascript("window.glanceReady === true", in: controller) as? Bool == true },
	"Initial preview ready"
)
_ = javascript("window.scrollTo(0, 900); true", in: controller)
let before = (javascript("window.scrollY", in: controller) as? NSNumber)?.doubleValue ?? 0
var active = controller
var reloads = 0
let observer = LivePreviewObserver(url: file) {
	guard let html = try? String(contentsOf: file, encoding: .utf8) else {
		return false
	}
	let next = WebPreviewVC(html: html)
	active
		.transferState(to: next) { window.contentViewController = next; active = next; reloads += 1
		}
	return true
}

observer.start()
try (longHTML + "<p>Atomic replacement</p>").write(to: file, atomically: true, encoding: .utf8)
check(wait { reloads == 1 }, "Observer detects stable atomic replacement")
check(
	wait { javascript("window.glanceReady === true", in: active) as? Bool == true },
	"Replacement renderer ready"
)
check(
	wait {
		let after = (javascript("window.scrollY", in: active) as? NSNumber)?
			.doubleValue ?? 0; return before > 0 && abs(after - before) < 3
	},
	"Actual scroll retained"
)
let moved = directory.appendingPathComponent("moved.html")
try FileManager.default.moveItem(at: file, to: moved)
_ = wait({ false }, seconds: 0.8)
check(reloads == 1, "Transient missing file retains last view")
try FileManager.default.moveItem(at: moved, to: file)
observer.stop()
try (longHTML + "<p>After stop</p>").write(to: file, atomically: true, encoding: .utf8)
_ = wait({ false }, seconds: 0.8)
check(reloads == 1, "Stopped observation does not refresh")
screenshot(active, name: "live-refresh")
window.close()

print("Failures: \(failures)")
exit(failures == 0 ? 0 : 1)
