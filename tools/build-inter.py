#!/usr/bin/env python3
"""Builds Bloom's Inter from the files Google Fonts serves Bloom's stylesheet
(Inter, weights 400 to 700): one WOFF2 per script subset, each variable on
weight only. These differ from google/fonts' repository build; measured
through Qt they match Chromium's widths, the repository build doesn't.
For each weight, every subset is instanced there and the subsets merged
into one static font, named "Bloom Inter" so an installed Inter never
stands in. Needs fontTools (with brotli for WOFF2).

Usage: build-inter.py <out-dir> <subset.woff2>...
"""
import os
import sys
import tempfile

from fontTools.merge import Merger
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

FAMILY = "Bloom Inter"
STYLES = {400: "Regular", 500: "Medium", 600: "SemiBold", 700: "Bold"}


def family_for(weight):
	# Qt's application-font matching confuses a regular and a medium face of
	# one family (both resolve to one of them), so Medium is a family of its
	# own; Regular, SemiBold and Bold share "Bloom Inter" and match by weight.
	return f"{FAMILY} Medium" if weight == 500 else FAMILY


def name(font, weight, style):
	names = font["name"]
	for record in list(names.names):
		names.removeNames(nameID=record.nameID)
	family = family_for(weight)
	shown = "Regular" if weight == 500 else style
	for name_id, text in {
		0: "Copyright 2020 The Inter Project Authors (https://github.com/rsms/inter)",
		1: family, 2: shown, 3: f"{FAMILY} {style};Google Fonts Inter v20",
		4: f"{FAMILY} {style}", 5: "Google Fonts Inter v20", 6: f"BloomInter-{style}",
		13: "SIL Open Font License 1.1 (see OFL.txt)", 16: family, 17: shown,
	}.items():
		names.setName(text, name_id, 3, 1, 0x409)
	font["OS/2"].usWeightClass = weight
	font["OS/2"].fsSelection = (font["OS/2"].fsSelection & ~0b1100001) | (0b100000 if style == "Bold" else 0b1000000 if shown == "Regular" else 0)
	font["head"].macStyle = 1 if style == "Bold" else 0


def build(out_dir, subsets):
	with tempfile.TemporaryDirectory() as tmp:
		for weight, style in STYLES.items():
			parts = []
			for i, path in enumerate(subsets):
				font = instantiateVariableFont(TTFont(path), {"wght": weight}, updateFontNames=False)
				for table in ("STAT", "fvar", "avar", "HVAR", "MVAR", "gvar"):
					if table in font:
						del font[table]
				font.flavor = None
				part = os.path.join(tmp, f"{weight}-{i}.ttf")
				font.save(part)
				parts.append(part)
			merged = Merger().merge(parts)
			name(merged, weight, style)
			out = os.path.join(out_dir, f"BloomInter-{weight}.ttf")
			merged.save(out)
			print(f"wrote {out}")


if __name__ == "__main__":
	if len(sys.argv) < 3:
		raise SystemExit(__doc__)
	build(sys.argv[1], sys.argv[2:])
