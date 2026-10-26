# Standalone launcher

The bundled `Glance.app/Contents/Resources/glance` command opens files in a Glance window using the existing upstream preview controllers. It does not require the rich-preview contribution.

```sh
scripts/build-local.sh
scripts/test-standalone-launcher.sh /path/to/built/Glance.app
ln -s /Applications/Glance.app/Contents/Resources/glance ~/.local/bin/glance
glance README.md
glance --check README.md
glance --quick-look README.md
glance --version
```

Build requirements are full Xcode, Go and the existing Xcode package dependencies. The local build script produces an ad-hoc signed universal app and prints its path; it does not install or activate it. Release signing and notarization remain maintainer responsibilities.

By default the command asks Glance to open the selected local files. `--quick-look` uses the system Quick Look panel and installed providers instead. `--check` prints content type identifiers without opening previews. The launcher must remain inside the app bundle; expose it through a symlink rather than copying the binary.

Markdown, source code, notebooks, TSV and supported archives use upstream renderers. Readable TypeScript `.ts` source bypasses Finder's video-type arbitration. Images, PDFs and media use Apple's native Quick Look view; source that cannot be read as UTF-8 falls back to that view. Windows remember their size and release their preview when closed. Non-native source previews retain the existing 10 MB limit and archive handling retains upstream behavior.

Folders and SQLite databases are rejected explicitly. CSV continues to use upstream source rendering; this contribution does not add CSV table support. It also does not add Mermaid/math, WKWebView migration, live refresh, display controls, scroll preservation or Markdown image-folder authorization. These can be considered separately.

The focused verification script compiles the actual upstream renderers and standalone controller against the built app's dependencies and resources. It creates windows without showing or ordering them, checks TypeScript/Markdown/TSV routing, native image and binary fallback, rejected inputs, the source size limit and cleanup on close. It saves an offscreen TSV content snapshot for visual inspection. It does not activate the application or grant permissions. Interactive launcher opening and system-provider rendering require separate manual verification.
