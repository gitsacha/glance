// swiftformat:disable wrapMultilineStatementBraces
import Cocoa
import Quartz
import UniformTypeIdentifiers

/// The same preview controllers as the extension, without Finder's content-type arbitration.
final class PreviewWindowController: NSWindowController, NSWindowDelegate {
	let fileURL: URL
	var onClose: (() -> Void)?
	private var fileScopeActive = false

	init(fileURL: URL) throws {
		guard fileURL.isFileURL else {
			throw FileError.fileReadError(
				path: fileURL.path,
				message: "Only local files can be previewed"
			)
		}
		self.fileURL = fileURL
		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 900, height: 650),
			styleMask: [.titled, .closable, .miniaturizable, .resizable],
			backing: .buffered,
			defer: false
		)
		super.init(window: window)
		window.title = fileURL.lastPathComponent
		window.representedURL = fileURL
		window.minSize = NSSize(width: 650, height: 400)
		window.isReleasedWhenClosed = false
		window.setFrameAutosaveName("GlanceStandalonePreview")
		window.delegate = self
		fileScopeActive = fileURL.startAccessingSecurityScopedResource()
		try reload()
	}

	@available(*, unavailable)
	required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

	deinit {
		if fileScopeActive { fileURL.stopAccessingSecurityScopedResource() }
	}

	func reload() throws {
		let file = try File(url: fileURL)
		guard !file.isDirectory,
		      !["db", "sqlite", "sqlite3"].contains(fileURL.pathExtension.lowercased()) else {
			throw FileError.fileReadError(
				path: file.path,
				message: "Folder and database previews are not supported"
			)
		}
		let contentType = try? fileURL.resourceValues(forKeys: [.contentTypeKey]).contentType
		let nativeTypes: [UTType] = [.image, .pdf, .audiovisualContent, .spreadsheet, .presentation]
		let isTypeScript = fileURL.pathExtension.lowercased() == "ts" && file
			.size <= 10_000_000 && (try? file.read()) != nil
		if !isTypeScript, let contentType = contentType,
		   nativeTypes.contains(where: { contentType.conforms(to: $0) }) {
			install(NativePreviewVC(fileURL: fileURL))
			return
		}
		guard file.isArchive || file.size <= 10_000_000 else {
			throw FileError.fileReadError(
				path: file.path,
				message: "File exceeds the 10 MB preview limit"
			)
		}
		guard let type = PreviewVCFactory.getPreviewInitializer(fileURL: fileURL) else {
			throw FileError.fileReadError(path: file.path, message: "Unsupported file")
		}
		let preview = type.init()
		do { install(try preview.createPreviewVC(file: file)) } catch {
			if preview is CodePreview {
				install(NativePreviewVC(fileURL: fileURL))
			} else { throw error }
		}
	}

	private func install(_ next: NSViewController) {
		window?.contentViewController = next
	}

	func windowWillClose(_: Notification) {
		window?.contentViewController = nil
		onClose?()
	}
}

/// Apple-owned document/media types retain their native rendering inside the same app window.
final class NativePreviewVC: NSViewController {
	private weak var previewView: QLPreviewView?
	let fileURL: URL
	init(fileURL: URL) {
		self.fileURL = fileURL
		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
	required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }
	override func loadView() {
		let preview = QLPreviewView(
			frame: NSRect(x: 0, y: 0, width: 900, height: 650),
			style: .normal
		)!
		preview.previewItem = fileURL as NSURL
		view = preview
		previewView = preview
	}

	deinit { previewView?.close() }
}
