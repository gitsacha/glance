# Web preview controls and heading navigation

Add a native Find/Next/Copy toolbar, font size, wrapping and appearance controls, with a heading Contents sidebar. Source copies preserve the accepted source rather than rendered text. Settings persist in the existing app/extension defaults. Canonical Markdown heading IDs come from Goldmark.

Depends only on the web-modernization patch. The exported delta excludes its dependency; the worktree includes both so it builds without commits. No Mermaid/math, image embedding or live refresh is introduced.
