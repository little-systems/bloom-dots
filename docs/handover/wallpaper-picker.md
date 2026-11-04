# Wallpaper library and custom selection

The picker follows ii's useful file-browser behaviors (folder selection,
search, readable filenames and keyboard navigation) while retaining Bloom's
theme and opening motion. It does not run ii's wallpaper scripts.

- The selected library is scanned recursively, including linked files/folders.
  Previously only top-level regular files were included. Results are sorted and
  deduplicated; NUL-delimited discovery preserves newlines and special characters.
- Choose folder, editable absolute/`~/` folder path, Up, Default and Refresh
  navigate/rescan the library. Invalid folders leave the previous selection intact.
- Open file selects an individual wallpaper outside the library. Desktop dialogs
  use the same installed backends as the dock (kdialog, zenity or qarma). The layer
  picker releases input and hides until the desktop dialog exits. Cancel keeps the
  wallpaper; an unavailable backend reports an error without installing packages.
- Search matches words across filenames and subfolder paths. Filenames, current
  wallpaper marker, count, loading/error states and a separate scroll gutter remain
  visible. Enter applies the selection; Escape or outside click closes the picker.
- Additional image extensions include AVIF, SVG and GIF; decoding depends on the
  installed Qt image plugins. Videos retain a labeled fallback rather than a fake
  thumbnail. The directory scan has a 30-second deadline and reports partial-read
  failures. Recursive traversal has no file-count/byte cap yet.

Focused validation: wallpaper logic and picker QML checks, isolated shell library,
custom folder and invalid-folder recovery, controlled dialog result/cancellation/
missing-backend tests. Real kdialog file and folder acceptance were also exercised
with keyboard input in a separate compositor. Screenshots were inspected before
updating the live shell. No complete suite was run for this change.
