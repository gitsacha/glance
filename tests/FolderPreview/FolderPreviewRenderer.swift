// swiftformat:disable wrapMultilineStatementBraces
import Cocoa
import SQLite3
import WebKit

@main
struct RendererCheck {
	static func main() throws {
		_ = NSApplication.shared
		let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
		func check(_ condition: Bool, _ message: String) {
			precondition(condition, message); print("PASS: \(message)")
		}
		func fixture(_ name: String, _ value: String) throws -> URL {
			let url = directory.appendingPathComponent(name)
			try value.write(to: url, atomically: true, encoding: .utf8)
			return url
		}
		let url = directory.appendingPathComponent("Tree")
		try FileManager.default.createDirectory(
			at: url.appendingPathComponent("Nested"),
			withIntermediateDirectories: true
		)
		try "sample".write(
			to: url.appendingPathComponent("Nested/<unsafe>.txt"),
			atomically: true,
			encoding: .utf8
		)
		let controller = try FolderPreview().createPreviewVC(file: File(url: url))
		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 900, height: 650),
			styleMask: [.borderless],
			backing: .buffered,
			defer: false
		)
		window.contentViewController = controller
		controller.view.frame = NSRect(x: 0, y: 0, width: 900, height: 650)
		controller.view.layoutSubtreeIfNeeded()
		let web = controller.view.subviews.compactMap { $0 as? WebView }.first!
		func evaluate(_ script: String) -> String { web
			.stringByEvaluatingJavaScript(from: script) ?? ""
		}
		let deadline = Date().addingTimeInterval(10)
		while evaluate("document.body ? document.body.textContent : ''")
			.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
			Date() < deadline {
			RunLoop.current.run(until: Date().addingTimeInterval(0.05))
		}
		let text = evaluate("document.body.textContent")
		check(!text.isEmpty, "actual WebView document loaded")
		check(
			text.contains("Tree") && text.contains("Nested"),
			"folder heading and nested details render"
		)
		check(
			evaluate("document.querySelectorAll('details').length") == "1",
			"folder details DOM exists"
		)
		_ = evaluate("document.querySelector('details').open = true")
		check(
			evaluate("document.body.textContent.includes('<unsafe>.txt')") == "true",
			"escaped filename renders as text"
		)
		RunLoop.current.run(until: Date().addingTimeInterval(0.2))
		controller.view.displayIfNeeded()
		let bitmap = controller.view.bitmapImageRepForCachingDisplay(in: controller.view.bounds)!
		controller.view.cacheDisplay(in: controller.view.bounds, to: bitmap)
		try bitmap.representation(using: .png, properties: [:])!
			.write(to: directory.appendingPathComponent("folder-preview.png"))
		check(!window.isVisible, "window remains offscreen")
	}
}
