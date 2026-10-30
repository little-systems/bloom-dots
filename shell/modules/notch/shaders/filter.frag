#version 440
// The second blur pass, then CSS's filter chain on the result:
// saturate() contrast() brightness() (Filter Effects 1 matrices, each
// clamped), then the element's opacity.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
	mat4 qt_Matrix;
	float qt_Opacity;
	vec2 delta;
	float saturate;
	float contrast;
	float brightness;
	float alpha;
};
layout(binding = 1) uniform sampler2D source;

void main() {
	vec4 sum = vec4(0.0);
	float total = 0.0;
	for (int i = -24; i <= 24; ++i) {
		float t = float(i) / 8.0;
		float w = exp(-0.5 * t * t);
		sum += w * texture(source, qt_TexCoord0 + delta * t);
		total += w;
	}
	vec4 p = sum / total;
	if (p.a <= 0.0) {
		fragColor = vec4(0.0);
		return;
	}
	vec3 c = p.rgb / p.a;
	float s = saturate;
	mat3 sat = mat3(
		0.213 + 0.787 * s, 0.213 - 0.213 * s, 0.213 - 0.213 * s,
		0.715 - 0.715 * s, 0.715 + 0.285 * s, 0.715 - 0.715 * s,
		0.072 - 0.072 * s, 0.072 - 0.072 * s, 0.072 + 0.928 * s);
	c = clamp(sat * c, 0.0, 1.0);
	c = clamp((c - 0.5) * contrast + 0.5, 0.0, 1.0);
	c = clamp(c * brightness, 0.0, 1.0);
	float a = p.a * alpha * qt_Opacity;
	fragColor = vec4(c * a, a);
}
