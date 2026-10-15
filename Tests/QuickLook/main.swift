import Cocoa
import Quartz

/// An actual Quick Look service probe, with its own window kept outside every screen.
final class OffscreenWindow: NSWindow {
	override func constrainFrameRect(_ frameRect: NSRect, to _: NSScreen?) -> NSRect { frameRect }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let preview = QLPreviewView(frame: NSRect(x: 0, y: 0, width: 900, height: 700), style: .normal)!
let window = OffscreenWindow(
	contentRect: NSRect(x: -100_000, y: -100_000, width: 900, height: 700),
	styleMask: .borderless,
	backing: .buffered,
	defer: false
)
window.contentView = preview
window.orderBack(nil)
for path in CommandLine.arguments.dropFirst() {
	preview.previewItem = URL(fileURLWithPath: path) as NSURL
	preview.refreshPreviewItem()
	let deadline = Date().addingTimeInterval(3)
	while Date() < deadline {
		RunLoop.current.run(until: Date().addingTimeInterval(0.05))
	}
	print("Requested installed preview: \(URL(fileURLWithPath: path).lastPathComponent)")
}

preview.close()
window.orderOut(nil)
