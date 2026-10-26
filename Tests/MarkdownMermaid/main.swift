import Cocoa
import Foundation
import WebKit

let application = NSApplication.shared
application.setActivationPolicy(.prohibited)
func check(_ value: Bool, _ message: String) {
	if !value { fatalError(message) }
	print("PASS: " + message)
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
	.appendingPathComponent("QLPlugin/Resources")
let web = WebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
let scripts = ["markdown/markdown-mermaid.min.js", "markdown/markdown-mermaid.js"]
	.map { name -> String in
		if name == "markdown/markdown-mermaid.js" {
			let source = try! String(contentsOf: root.appendingPathComponent(name), encoding: .utf8)
			return "<script>window.glanceReady = true; window.readyEvents = 0; document.addEventListener('glance-ready', () => { window.readyEvents++; window.renderedAtReady = !!document.querySelector('.mermaid svg') && window.glanceReady === true; });" +
				source + ";window.immediatePending = window.glanceReady === false && window.readyEvents === 0;</script>"
		}
		return "<script src=\"" + root.appendingPathComponent(name).path + "\"></script>"
	}
	.joined()
web.mainFrame.loadHTMLString(
	"<html><body><div class=\"markdown-body\"><pre><code class=\"language-mermaid\">graph TD; A-->B;</code></pre></div>" +
		scripts + "</body></html>",
	baseURL: root
)
let deadline = Date().addingTimeInterval(30)
while Date() < deadline {
	RunLoop.current.run(until: Date().addingTimeInterval(0.05))
	if web
		.stringByEvaluatingJavaScript(
			from: "window.glanceReady === true && window.readyEvents === 1"
		) ==
		"true" { break }
}

check(
	web.stringByEvaluatingJavaScript(from: "!!document.querySelector('.mermaid svg')") == "true",
	"diagram renders"
)
check(
	web
		.stringByEvaluatingJavaScript(
			from: "document.querySelectorAll('.glance-diagram-controls button').length === 3"
		) ==
		"true",
	"zoom controls render"
)
check(
	web
		.stringByEvaluatingJavaScript(from: "document.querySelectorAll('script').length === 2") ==
		"true",
	"only Mermaid scripts included"
)
let initialWidth = web
	.stringByEvaluatingJavaScript(from: "document.querySelector('.mermaid svg').style.width")
_ = web
	.stringByEvaluatingJavaScript(
		from: "document.querySelectorAll('.glance-diagram-controls button')[2].click()"
	)
check(
	web
		.stringByEvaluatingJavaScript(from: "document.querySelector('.mermaid svg').style.width") !=
		initialWidth,
	"zoom increases width"
)
_ = web
	.stringByEvaluatingJavaScript(
		from: "document.querySelectorAll('.glance-diagram-controls button')[1].click()"
	)
check(
	web
		.stringByEvaluatingJavaScript(from: "document.querySelector('.mermaid svg').style.width") ==
		initialWidth,
	"reset restores width"
)
check(
	web.stringByEvaluatingJavaScript(from: "window.immediatePending === true") == "true",
	"readiness is pending synchronously before queued rendering"
)
check(
	web
		.stringByEvaluatingJavaScript(
			from: "window.glanceReady === true && window.readyEvents === 1 && window.renderedAtReady === true"
		) ==
		"true",
	"ready event follows completed diagram rendering"
)
check(
	web
		.stringByEvaluatingJavaScript(
			from: "(() => { const node = document.querySelector('.mermaid'), svg = node.querySelector('svg'), before = svg.getBoundingClientRect(); node.style.width = '40px'; const after = svg.getBoundingClientRect(); const valid = getComputedStyle(node).textAlign === 'center' && getComputedStyle(svg).maxWidth === '100%' && parseFloat(getComputedStyle(svg).height) > 0 && after.width <= 40 && after.height < before.height && Math.abs(after.width / after.height - before.width / before.height) < 0.02; node.style.width = ''; return valid; })()"
		) ==
		"true",
	"diagram stays centered and responsive with automatic height"
)
web.layoutSubtreeIfNeeded()
if let bitmap = web.bitmapImageRepForCachingDisplay(in: web.bounds) {
	web.cacheDisplay(in: web.bounds, to: bitmap)
	try bitmap.representation(using: .png, properties: [:])!
		.write(to: URL(fileURLWithPath: CommandLine.arguments[1])
			.appendingPathComponent("mermaid.png"))
	print("Screenshot: " + CommandLine.arguments[1] + "/mermaid.png")
}
