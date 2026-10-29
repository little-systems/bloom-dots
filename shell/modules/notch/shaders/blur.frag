#version 440
// One pass of a separable Gaussian blur: 49 taps across ±3σ along `delta`,
// which is σ in texture coordinates.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
	mat4 qt_Matrix;
	float qt_Opacity;
	vec2 delta;
};
layout(binding = 1) uniform sampler2D source;

vec4 blurred() {
	vec4 sum = vec4(0.0);
	float total = 0.0;
	for (int i = -24; i <= 24; ++i) {
		float t = float(i) / 8.0;
		float w = exp(-0.5 * t * t);
		sum += w * texture(source, qt_TexCoord0 + delta * t);
		total += w;
	}
	return sum / total;
}

void main() {
	fragColor = blurred() * qt_Opacity;
}
