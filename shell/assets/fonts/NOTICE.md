# Bloom Inter

`BloomInter-400/500/600/700.ttf` are the Inter files Google Fonts serves for
Bloom's stylesheet (`fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700`),
the font Bloom draws with: each script subset instanced at the weight and
merged into one file. Google's served build differs from google/fonts'
repository build; these match Chromium's widths. Only the names are
changed, to "Bloom Inter", so the shell draws exactly this build even where
another Inter is installed. Rebuild them with `tools/fetch-inter.sh`.

Copyright 2020 The Inter Project Authors (https://github.com/rsms/inter).
Licensed under the SIL Open Font License 1.1: see `OFL.txt`.
