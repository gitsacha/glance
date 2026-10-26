# table-navigation

Depends on the csv-preview snapshot, not upstream alone. Adds stable numeric/text sorting, blank cells last, and 100-row pages to its positional native table. The exported patch is only the delta from CSV.

Validation: isolated Release Xcode build; headless production routing/data checks; strict SwiftLint and SwiftFormat 0.58.6; unchanged Go converter tests and lint. Actual production controllers were rendered in unshown offscreen windows, with native table/legacy WebView assertions and inspected PNG captures. No windows were shown.
