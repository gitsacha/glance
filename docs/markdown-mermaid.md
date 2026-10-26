# Markdown mermaid

Independent contribution against upstream c6225d8, using the existing WebView, Script and Stylesheet APIs. No toolbar, launcher or web-controller modernization dependency.

Bundles Mermaid 11.17.2 with its MIT license and integrity-pinned updater. Strict diagrams are capped at 20, 50,000 characters and 500 edges. Keeps accessible bounded zoom and serialized appearance redraws.

Run scripts/test-markdown-mermaid.sh for headless rendering checks. No application activation or window ordering. Build using xcodebuild with a disposable derivedDataPath; never make all.

Validation on 26 October 2026: universal Release Xcode build passed (arm64 and x86_64, signing disabled, macOS 12 deployment target); 8 focused headless checks passed using the existing legacy WebView (image checks compile the actual MarkdownPreview with minimal unrelated type stubs); strict SwiftLint and pinned SwiftFormat 0.58.6 lint passed. Existing SwiftLint renamed-rule warnings and WebView deprecation warnings remain. No app activation, window ordering, installed-app changes, Finder registration, commits or publication.

Integration: combine the focused MarkdownPreview edits when stacking these independent patches; math and Mermaid share no feature code. The modernization slice must retain .markdown-body as the content root and permit the bundled JS/CSS/font resources. Standalone folder-grant support and live refresh belong to their own contributions.

Vendor preservation: Mermaid is byte-for-byte from the integrity-verified npm archive; its upstream minified file contains trailing whitespace. Whitespace checks exclude that vendor file.

Readiness becomes false synchronously before queued diagram rendering, including appearance redraws; the ready event follows completed rendering. The headless test starts from a stale true flag and checks both transitions.

Diagram styling preserves centered diagrams with responsive maximum width and automatic SVG height.
