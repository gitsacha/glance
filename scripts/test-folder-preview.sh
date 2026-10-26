#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
scratch="$(mktemp -d "${TMPDIR:-/tmp}/glance-preview-test.XXXXXX")"
swiftc tests/FolderPreview/PreviewStubs.swift QLPlugin/Utils/File.swift QLPlugin/Views/Previews/FolderPreview.swift tests/FolderPreview/main.swift -o "$scratch/test" -lsqlite3
"$scratch/test"
