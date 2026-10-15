// swiftformat:disable wrapMultilineStatementBraces
import Cocoa
import SQLite3

func escapedHTML(_ text: String) -> String {
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

/// SQLite is opened read-only. Only ordinary tables are selected; no user SQL or extensions run.
class DatabasePreview: Preview {
	required init() {}

	func createPreviewVC(file: File) throws -> PreviewVC {
		var database: OpaquePointer?
		guard sqlite3_open_v2(
			file.path,
			&database,
			SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX,
			nil
		) == SQLITE_OK,
			let connection = database
		else {
			if database != nil {
				sqlite3_close(database)
			}
			throw FileError.fileReadError(
				path: file.path,
				message: "Not a readable SQLite database"
			)
		}
		defer { sqlite3_close(connection) }
		sqlite3_busy_timeout(connection, 200)
		sqlite3_limit(connection, SQLITE_LIMIT_LENGTH, 1_000_000)
		sqlite3_limit(connection, SQLITE_LIMIT_COLUMN, 200)
		sqlite3_exec(connection, "PRAGMA query_only=ON; PRAGMA trusted_schema=OFF", nil, nil, nil)
		let deadline = Date().addingTimeInterval(2)
		let deadlinePointer = UnsafeMutablePointer<Date>.allocate(capacity: 1)
		deadlinePointer.initialize(to: deadline)
		defer { deadlinePointer.deinitialize(count: 1); deadlinePointer.deallocate() }
		sqlite3_progress_handler(
			connection,
			1000,
			{ context in
				guard let context = context else {
					return 1
				}
				return Date() > context.assumingMemoryBound(to: Date.self).pointee ? 1 : 0
			},
			deadlinePointer
		)
		var statement: OpaquePointer?
		let sql = "SELECT name FROM sqlite_schema WHERE type='table' AND name NOT LIKE 'sqlite_%' AND upper(sql) NOT LIKE 'CREATE VIRTUAL%' ORDER BY name LIMIT 50"
		guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK else {
			throw FileError.fileReadError(path: file.path, message: "Cannot read SQLite schema")
		}
		defer { sqlite3_finalize(statement) }
		var names: [String] = []
		while sqlite3_step(statement) == SQLITE_ROW {
			if let text = sqlite3_column_text(statement, 0) {
				names.append(String(cString: text))
			}
		}
		var html = "<h1>\(escapedHTML(file.url.lastPathComponent))</h1><p>Read-only · first 200 rows per table · at most 50 tables</p>"
		for name in names {
			if Date() > deadline || html.utf8.count > 2_000_000 { break }
			let quoted = "\"" + name.replacingOccurrences(of: "\"", with: "\"\"") + "\""
			var rows: OpaquePointer?
			guard sqlite3_prepare_v2(
				connection,
				"SELECT * FROM \(quoted) LIMIT 201",
				-1,
				&rows,
				nil
			) == SQLITE_OK else { continue }
			defer { sqlite3_finalize(rows) }
			html += "<details><summary>\(escapedHTML(name))</summary><div style=\"overflow:auto\"><table><thead><tr>"
			let columns = sqlite3_column_count(rows)
			for index in 0 ..<
				columns {
				html +=
					"<th>\(escapedHTML(String(cString: sqlite3_column_name(rows, index))))</th>"
			}
			html += "</tr></thead><tbody>"
			var count = 0
			while sqlite3_step(rows) == SQLITE_ROW {
				if Date() > deadline || html.utf8.count > 2_000_000 { break }
				guard count < 200
				else { html += "<tr><td>Additional rows omitted.</td></tr>"; break }
				count += 1
				html += "<tr>"
				for index in 0 ..< columns {
					let value: String
					if sqlite3_column_type(rows, index) ==
						SQLITE_BLOB {
						value = "[BLOB: \(sqlite3_column_bytes(rows, index)) bytes]"
					} else if let text = sqlite3_column_text(rows, index) {
						value = String(String(cString: text).prefix(2000))
					} else {
						value = "NULL"
					}
					html += "<td>\(escapedHTML(value))</td>"
				}
				html += "</tr>"
			}
			html += "</tbody></table></div></details>"
		}
		if Date() > deadline {
			html += "<p>Preview time limit reached.</p>"
		}
		return WebPreviewVC(html: html)
	}
}
