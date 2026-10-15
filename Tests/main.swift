// swiftformat:disable wrapMultilineStatementBraces
import Cocoa
import SQLite3
import WebKit

let application = NSApplication.shared
application.setActivationPolicy(.prohibited)
var failures = 0
func check(_ condition: Bool, _ message: String) {
	if condition {
		print("PASS: \(message)")
	} else {
		print("FAIL: \(message)"); failures += 1
	}
}

func wait(until condition: () -> Bool, seconds: TimeInterval = 15) -> Bool {
	let deadline = Date().addingTimeInterval(seconds)
	while !condition(),
	      Date() < deadline {
		RunLoop.current.run(until: Date().addingTimeInterval(0.02))
	}
	return condition()
}

func javascript(_ script: String, in controller: WebPreviewVC) -> Any? {
	var done = false
	var result: Any?
	controller.webView.evaluateJavaScript(script) { value, error in
		if let error = error {
			print("JavaScript: \(error.localizedDescription)")
		}
		result = value; done = true
	}
	_ = wait(until: { done })
	return result
}

let directory = URL(fileURLWithPath: CommandLine.arguments[1])
	.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
print("TEST_OUTPUT=\(directory.path)")
let markdown = directory.appendingPathComponent("preview.md")
try """
# Developer previews

## Diagram

```mermaid
flowchart LR
 A[Code] --> B[Preview]
```

## Math

$$E = mc^2$$

<script>window.untrustedScriptExecuted = true</script>

[Remote](https://example.com)
""".write(to: markdown, atomically: true, encoding: .utf8)
let controller = try MarkdownPreview().createPreviewVC(file: File(url: markdown)) as! WebPreviewVC
let window = NSWindow(
	contentRect: NSRect(x: -3000, y: -3000, width: 1000, height: 750),
	styleMask: [.borderless],
	backing: .buffered,
	defer: false
)
window.contentViewController = controller
controller.view.layoutSubtreeIfNeeded()
check(
	wait(until: { javascript(
		"window.glanceReady === true && !!document.querySelector('.mermaid svg')",
		in: controller
	) as? Bool == true }),
	"Markdown and bundled Mermaid finish rendering"
)
check(
	javascript("document.querySelectorAll('.katex').length > 0", in: controller) as? Bool == true,
	"KaTeX math renders offline"
)
check(
	javascript(
		"document.querySelectorAll('#glance-toc a').length === 3",
		in: controller
	) as? Bool ==
		true,
	"Contents contains heading anchors"
)
check(
	javascript("window.untrustedScriptExecuted === undefined", in: controller) as? Bool == true,
	"Markdown script is not executed"
)
check(
	javascript(
		"document.querySelector('meta[http-equiv]').content.includes(\"connect-src 'none'\")",
		in: controller
	) as? Bool == true,
	"Network requests blocked by CSP"
)
_ = javascript(
	"window.cspBlocked = false; document.addEventListener('securitypolicyviolation', e => { if (e.violatedDirective === 'connect-src') window.cspBlocked = true; }); fetch('https://example.invalid/').catch(() => {}); true",
	in: controller
)
check(
	wait(until: { javascript("window.cspBlocked", in: controller) as? Bool == true }),
	"WebKit actually rejects network fetches through CSP"
)

var toolbarCaptured = false
if let stack = controller.view.subviews.first as? NSStackView,
   let toolbar = stack.arrangedSubviews.first,
   let bitmap = toolbar.bitmapImageRepForCachingDisplay(in: toolbar.bounds) {
	toolbar.cacheDisplay(in: toolbar.bounds, to: bitmap)
	if let context = CGContext(
		data: nil,
		width: bitmap.pixelsWide,
		height: bitmap.pixelsHigh,
		bitsPerComponent: 8,
		bytesPerRow: 0,
		space: CGColorSpaceCreateDeviceRGB(),
		bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
	),
		let original = bitmap.cgImage {
		let bounds = CGRect(x: 0, y: 0, width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
		context.setFillColor(CGColor(gray: 1, alpha: 1))
		context.fill(bounds)
		context.draw(original, in: bounds)
		if let result = context.makeImage(),
		   let png = NSBitmapImageRep(cgImage: result)
		   .representation(using: .png, properties: [:]) {
			try png.write(to: directory.appendingPathComponent("toolbar.png"))
			toolbarCaptured = true
		}
	}
}

check(toolbarCaptured, "Native toolbar screenshot captured for visual inspection")

var snapshotDone = false
controller.webView.takeSnapshot(with: nil) { image, error in
	defer { snapshotDone = true }
	guard let image = image, let tiff = image.tiffRepresentation,
	      let bitmap = NSBitmapImageRep(data: tiff) else {
		print("Snapshot: \(String(describing: error))")
		failures += 1
		return
	}
	guard let png = bitmap.representation(using: .png, properties: [:]) else {
		failures += 1
		return
	}
	do {
		try png.write(to: directory.appendingPathComponent("markdown.png"))
	} catch {
		print(error)
		failures += 1
	}
}

check(wait(until: { snapshotDone }), "WebKit snapshot completed")
let lightFill = javascript(
	"getComputedStyle(document.querySelector('.mermaid svg rect')).fill",
	in: controller
) as? String
controller.webView.appearance = NSAppearance(named: .darkAqua)
check(wait(until: {
	(javascript(
		"getComputedStyle(document.querySelector('.mermaid svg rect')).fill",
		in: controller
	) as? String) != lightFill
}, seconds: 3), "Mermaid redraws when the preview changes to dark appearance")

let jsonURL = directory.appendingPathComponent("data.json")
try #"{"hello":{"n":1}}"#.write(to: jsonURL, atomically: true, encoding: .utf8)
check(
	try CodePreview().getSource(file: File(url: jsonURL)).contains("\n"),
	"JSON is pretty printed"
)
let plistURL = directory.appendingPathComponent("data.plist")
try PropertyListSerialization
	.data(fromPropertyList: ["hello": "world"], format: .binary, options: 0).write(to: plistURL)
check(
	try CodePreview().getSource(file: File(url: plistURL)).contains("<string>world</string>"),
	"Binary plist decompiled without execution"
)
let folder = directory.appendingPathComponent("folder")
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
try "safe".write(
	to: folder.appendingPathComponent("<unsafe>.txt"),
	atomically: true,
	encoding: .utf8
)
try FileManager.default.createSymbolicLink(
	atPath: folder.appendingPathComponent("loop").path,
	withDestinationPath: folder.path
)
let folderVC = try FolderPreview().createPreviewVC(file: File(url: folder)) as! WebPreviewVC
check(
	folderVC.html.contains("&lt;unsafe&gt;.txt"),
	"Folder names escaped and symlink loop is not followed"
)
let databaseURL = directory.appendingPathComponent("sample.sqlite")
var db: OpaquePointer?
sqlite3_open(databaseURL.path, &db)
sqlite3_exec(
	db,
	"CREATE TABLE sample (name TEXT); INSERT INTO sample VALUES ('<unsafe>');",
	nil,
	nil,
	nil
)
sqlite3_close(db)
let before = try Data(contentsOf: databaseURL)
let dbVC = try DatabasePreview().createPreviewVC(file: File(url: databaseURL)) as! WebPreviewVC
check(dbVC.html.contains("&lt;unsafe&gt;"), "SQLite table is previewed with escaped values")
check(try Data(contentsOf: databaseURL) == before, "SQLite file unchanged by preview")
check(
	!FileManager.default.fileExists(atPath: databaseURL.path + "-journal"),
	"SQLite preview creates no journal"
)
do { _ = try HTMLRenderer.renderNotebook("invalid"); check(false, "Renderer errors propagate")
} catch { check(
	true,
	"Renderer errors propagate"
) }

// Real parsers, not a mirrored reimplementation: duplicate headers, quoting and short rows.
let csvURL = directory.appendingPathComponent("quoted.csv")
try "name,name,notes\nAlice,Bob,\"one,two\"\nCarol\n".write(
	to: csvURL,
	atomically: true,
	encoding: .utf8
)
let csvVC = try TSVPreview().createPreviewVC(file: File(url: csvURL)) as! TablePreviewVC
check(csvVC.headers == ["name", "name", "notes"], "CSV duplicate headers are preserved")
check(csvVC.cells[0] == ["Alice", "Bob", "one,two"], "Quoted CSV cells parse correctly")
check(csvVC.cells[1] == ["Carol"], "Short CSV rows remain safe")
_ = csvVC.view
check(csvVC.view.fittingSize.width >= 0, "Native CSV view loads its nib")
for suffix in ["py", "ts", "tsx", "json", "yaml", "toml", "xml", "plist"] {
	let url = directory.appendingPathComponent("routing." + suffix)
	check(
		PreviewVCFactory.getPreviewInitializer(fileURL: url) is CodePreview.Type,
		"Source route: " + suffix
	)
}

check(
	PreviewVCFactory.getPreviewInitializer(fileURL: folder) is FolderPreview.Type,
	"Folder route selected"
)
check(
	PreviewVCFactory.getPreviewInitializer(fileURL: databaseURL) is DatabasePreview.Type,
	"SQLite route selected"
)
let imageURL = directory.appendingPathComponent("local.png")
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
try bitmap.representation(using: .png, properties: [:])!.write(to: imageURL)
let embedded = MarkdownPreview.inlineLocalImages(
	#"<img src="local.png" alt="local">"#,
	beside: markdown
)
check(
	embedded.contains("data:image/png;base64,"),
	"Accessible local image is embedded without broad file access"
)
let outside = directory.deletingLastPathComponent().appendingPathComponent("outside.png")
try Data(contentsOf: imageURL).write(to: outside)
let blocked = MarkdownPreview.inlineLocalImages(#"<img src="../outside.png">"#, beside: markdown)
check(!blocked.contains("base64"), "Images outside document directory are not read")
let nonImage = directory.appendingPathComponent("fake.png")
try "not an image".write(to: nonImage, atomically: true, encoding: .utf8)
check(
	!MarkdownPreview.inlineLocalImages(#"<img src="fake.png">"#, beside: markdown)
		.contains("base64"),
	"Non-image content is never embedded"
)

let standaloneCSV = try PreviewWindowController(fileURL: csvURL)
check(
	standaloneCSV.window?.contentViewController is TablePreviewVC,
	"Standalone window bypasses Finder's CSV ownership"
)
let typeScriptURL = directory.appendingPathComponent("source.ts")
try "export const answer: number = 42;".write(to: typeScriptURL, atomically: true, encoding: .utf8)
let standaloneTS = try PreviewWindowController(fileURL: typeScriptURL)
check(
	standaloneTS.window?.contentViewController is WebPreviewVC,
	"Standalone window previews TypeScript source without claiming TS video"
)
let documents = directory.appendingPathComponent("docs")
try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
let nestedMarkdown = documents.appendingPathComponent("images.md")
try "![Local](../local.png)".write(to: nestedMarkdown, atomically: true, encoding: .utf8)
let standaloneMarkdown = try PreviewWindowController(fileURL: nestedMarkdown)
try standaloneMarkdown.authorizeImageRoot(directory)
check(
	(standaloneMarkdown.window?.contentViewController as? WebPreviewVC)?.html
		.contains("data:image/png;base64,") == true,
	"Explicit project-folder access supports parent-directory Markdown images"
)
do { _ = try File(url: URL(string: "https://example.com/etc/hosts")!); check(
	false,
	"Remote URLs rejected before reading"
) } catch { check(true, "Remote URLs rejected before reading") }

let standaloneImage = try PreviewWindowController(fileURL: imageURL)
check(
	standaloneImage.window?.contentViewController is NativePreviewVC,
	"Standalone image keeps Apple's native preview inside Glance"
)

print("Failures: \(failures)")
exit(failures == 0 ? 0 : 1)
