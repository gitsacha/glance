import Foundation

let scratch = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: scratch) }
func check(_ condition: @autoclosure () throws -> Bool) rethrows {
	let result = try condition(); precondition(result)
}

try Data().write(to: scratch.appendingPathComponent("<unsafe>"))
try Data().write(to: scratch.appendingPathComponent(".hidden"))
try FileManager.default.createSymbolicLink(
	at: scratch.appendingPathComponent("link"),
	withDestinationURL: scratch
)
let html = try (FolderPreview().createPreviewVC(file: File(url: scratch)) as! WebPreviewVC).html
check(html.contains("&lt;unsafe&gt;")); check(!html.contains(".hidden")); check(html.count < 9999)
let nested = scratch.appendingPathComponent("a/b/c/d/e")
try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
try Data().write(to: nested.appendingPathComponent("never-visible"))
let bounded = try (FolderPreview().createPreviewVC(file: File(url: scratch)) as! WebPreviewVC).html
check(bounded.contains("Preview limit reached")); check(!bounded.contains("never-visible"))
print("PASS folder escaping, hidden files, symlink cycle and depth bound")
