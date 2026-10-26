// swiftformat:disable wrapMultilineStatementBraces
import Cocoa

private func escapedHTML(_ text: String) -> String {
	text.replacingOccurrences(of: "&", with: "&amp;")
		.replacingOccurrences(of: "<", with: "&lt;")
		.replacingOccurrences(of: ">", with: "&gt;")
		.replacingOccurrences(of: "\"", with: "&quot;")
}

/// Directory traversal is bounded, never follows symbolic links, and never enters app packages.
class FolderPreview: Preview {
	required init() {}

	func createPreviewVC(file: File) throws -> PreviewVC {
		var remaining = 2000
		func list(_ directory: URL, depth: Int) throws -> String {
			guard depth < 4, remaining > 0 else {
				return "<p>Preview limit reached.</p>"
			}
			let keys: Set<URLResourceKey> = [
				.isDirectoryKey,
				.isSymbolicLinkKey,
				.isPackageKey,
				.fileSizeKey,
			]
			guard let entries = FileManager.default.enumerator(
				at: directory,
				includingPropertiesForKeys: Array(keys),
				options: [
					.skipsHiddenFiles,
					.skipsSubdirectoryDescendants,
					.skipsPackageDescendants,
				]
			) else {
				throw FileError.fileReadError(
					path: directory.path,
					message: "Cannot enumerate folder"
				)
			}
			let children = entries.prefix(remaining + 1).compactMap { $0 as? URL }.sorted {
				$0.lastPathComponent
					.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
			}
			var result = "<ul>"
			for child in children {
				guard remaining > 0
				else { result += "<li>Preview limited to 2,000 entries.</li>"; break }
				remaining -= 1
				let values = try child.resourceValues(forKeys: keys)
				let name = escapedHTML(child.lastPathComponent)
				if values.isDirectory == true, values.isSymbolicLink != true,
				   values.isPackage != true {
					result += "<li><details><summary>📁 \(name)</summary>"
					result += (try? list(
						child,
						depth: depth + 1
					)) ?? "<p>Folder is not readable.</p>"
					result += "</details></li>"
				} else {
					let size = ByteCountFormatter.string(
						fromByteCount: Int64(values.fileSize ?? 0),
						countStyle: .file
					)
					result += "<li>\(name) <small>\(size)</small></li>"
				}
			}
			return result + "</ul>"
		}
		return WebPreviewVC(html: "<h1>\(escapedHTML(file.url.lastPathComponent))</h1>" + (try list(
			file.url,
			depth: 0
		)))
	}
}
