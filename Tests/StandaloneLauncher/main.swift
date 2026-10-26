// swiftformat:disable wrapMultilineStatementBraces
import Cocoa

let app = NSApplication.shared
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
var failures = 0
func check(_ condition: Bool, _ message: String) {
	print("\(condition ? "PASS" : "FAIL"): \(message)")
	if !condition { failures += 1 }
}

func fixture(_ name: String, _ contents: String) throws -> URL {
	let url = directory.appendingPathComponent(name)
	try contents.write(to: url, atomically: true, encoding: .utf8)
	return url
}

let source = try fixture("source.ts", "export const answer: number = 42;")
let sourceWindow = try PreviewWindowController(fileURL: source)
check(
	sourceWindow.window?.contentViewController is WebPreviewVC,
	"TypeScript uses Glance source renderer"
)
let markdown = try PreviewWindowController(fileURL: fixture("document.md", "# Standalone"))
check(markdown.window?.contentViewController is WebPreviewVC, "Markdown uses existing renderer")
let table = try PreviewWindowController(fileURL: fixture("table.tsv", "a\tb\n1\t2\n"))
check(table.window?.contentViewController is TablePreviewVC, "TSV uses existing table renderer")
let image = directory.appendingPathComponent("image.png")
let bitmap = NSBitmapImageRep(
	bitmapDataPlanes: nil,
	pixelsWide: 2,
	pixelsHigh: 2,
	bitsPerSample: 8,
	samplesPerPixel: 4,
	hasAlpha: true,
	isPlanar: false,
	colorSpaceName: .deviceRGB,
	bytesPerRow: 0,
	bitsPerPixel: 0
)!
try bitmap.representation(using: .png, properties: [:])!.write(to: image)
let native = try PreviewWindowController(fileURL: image)
check(native.window?.contentViewController is NativePreviewVC, "Images use native Quick Look")
let binary = directory.appendingPathComponent("binary.unknown")
try Data([0xFF, 0xFE, 0x00, 0x80]).write(to: binary)
let fallback = try PreviewWindowController(fileURL: binary)
check(
	fallback.window?.contentViewController is NativePreviewVC,
	"Unreadable source falls back to native Quick Look"
)
for url in [
	directory.appendingPathComponent("missing.md"),
	directory,
	try fixture("data.sqlite", "SQLite format 3"),
	URL(string: "https://example.com/test.md")!,
] {
	do {
		_ = try PreviewWindowController(fileURL: url)
		check(false, "Reject unsupported or missing input: \(url.lastPathComponent)")
	} catch { check(true, "Reject unsupported or missing input: \(url.lastPathComponent)") }
}

let huge = try fixture("huge.txt", String(repeating: "a", count: 10_000_001))
do {
	_ = try PreviewWindowController(fileURL: huge)
	check(false, "Source size limit enforced")
} catch { check(true, "Source size limit enforced") }
// Capture the actual renderer without showing or ordering its window.
let deadline = Date().addingTimeInterval(2)
while Date() < deadline {
	RunLoop.current.run(until: Date().addingTimeInterval(0.05))
}

if let view = table.window?.contentViewController?.view,
   let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
	view.cacheDisplay(in: view.bounds, to: bitmap)
	try bitmap.representation(using: .png, properties: [:])!
		.write(to: directory.appendingPathComponent("standalone-tsv.png"))
	check(true, "Captured offscreen TSV preview")
} else { check(false, "Captured offscreen TSV preview") }
var closed = false
sourceWindow.onClose = { closed = true }
sourceWindow.window?.close()
check(
	closed && sourceWindow.window?.contentViewController == nil,
	"Closing releases the preview and notifies its owner"
)
for controller in [markdown, table, native, fallback] {
	controller.window?.close()
}

print("Failures: \(failures)")
exit(failures == 0 ? 0 : 1)
