#version 320 es

#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform vec2 u_size;
uniform sampler2D u_texture;
uniform float u_intensity;
uniform float u_aux;

out vec4 frag_color;

vec2 sample_uv(vec2 uv) {
#ifdef IMPELLER_TARGET_OPENGLES
  return vec2(uv.x, 1.0 - uv.y);
#else
  return uv;
#endif
}

vec4 sample_input(vec2 uv) {
  return texture(u_texture, sample_uv(clamp(uv, 0.0, 1.0)));
}

float luminance(vec3 color) {
  return dot(color, vec3(0.299, 0.587, 0.114));
}

float hash21(vec2 p) {
  return fract(sin(dot(p, vec2(91.17, 217.43))) * 49231.2243);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;
  float strength = clamp(u_intensity, 0.0, 1.0);
  vec4 source = sample_input(uv);

  float gray = luminance(source.rgb);
  gray = (gray - 0.5) * (1.0 + 0.85 * strength) + 0.5;
  gray += u_aux;

  float grain = (hash21(uv * u_size * 0.55) - 0.5) * 0.08 * strength;
  gray += grain;

  float vignette = smoothstep(0.44, 0.92, distance(uv, vec2(0.5)));
  gray -= vignette * 0.06 * strength;

  gray = clamp(gray, 0.0, 1.0);
  frag_color = vec4(vec3(gray), source.a);
}
