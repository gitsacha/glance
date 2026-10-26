#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
scratch="$(mktemp -d "${TMPDIR:-/tmp}/glance-markdown-checks.XXXXXX")"
xcrun swiftc -framework Cocoa -framework WebKit Tests/MarkdownMermaid/main.swift -o "$scratch/checks"
"$scratch/checks" "$scratch"
