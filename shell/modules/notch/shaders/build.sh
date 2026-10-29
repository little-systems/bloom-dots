#!/bin/sh
# Recompiles the notch's shaders: each *.frag (Vulkan-style GLSL 440) into the
# *.frag.qsb that ShaderEffect loads. Needs Qt's qsb (qt6-shadertools).
set -e
cd "$(dirname "$0")"
QSB="${QSB:-/usr/lib/qt6/bin/qsb}"
for f in *.frag; do
	"$QSB" --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "$f.qsb" "$f"
done
