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
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;
  vec4 source = sample_input(uv);
  vec3 color = source.rgb;
  float strength = clamp(u_intensity, 0.0, 1.0);

  color.r *= 1.0 + 0.18 * strength;
  color.g *= 1.0 + 0.05 * strength;
  color.b *= 1.0 - 0.12 * strength;

  float luma = luminance(color);
  float highlight_mask = smoothstep(0.56, 0.94, luma);
  vec3 orange_glow = vec3(1.0, 0.62, 0.24);
  color = mix(color, mix(color, orange_glow, 0.22 * strength), highlight_mask * 0.58);

  color = (color - 0.5) * (1.0 + 0.15 * strength) + 0.5;

  float grain = hash21(uv * u_size * 0.35) - 0.5;
  color += grain * 0.045 * strength;

  float vignette = smoothstep(0.34, 0.82, distance(uv, vec2(0.5)));
  color *= 1.0 - vignette * 0.18 * strength;

  frag_color = vec4(clamp(color, 0.0, 1.0), source.a);
}
