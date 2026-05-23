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

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;
  vec2 pixel = 1.0 / max(u_size, vec2(1.0));
  float strength = clamp(u_intensity, 0.0, 1.0);
  vec4 source = sample_input(uv);

  vec3 soft =
      sample_input(uv).rgb * 0.36 +
      sample_input(uv + vec2(pixel.x, 0.0)).rgb * 0.16 +
      sample_input(uv - vec2(pixel.x, 0.0)).rgb * 0.16 +
      sample_input(uv + vec2(0.0, pixel.y)).rgb * 0.16 +
      sample_input(uv - vec2(0.0, pixel.y)).rgb * 0.16;

  vec3 high_frequency = source.rgb - soft;
  vec3 sharpened = source.rgb + high_frequency * (0.55 + 1.05 * strength);

  float local_contrast = luminance(source.rgb) - luminance(soft);
  sharpened += vec3(local_contrast * (0.18 + 0.32 * strength));

  vec3 wide_soft =
      sample_input(uv + vec2(pixel.x * 2.0, 0.0)).rgb * 0.12 +
      sample_input(uv - vec2(pixel.x * 2.0, 0.0)).rgb * 0.12 +
      sample_input(uv + vec2(0.0, pixel.y * 2.0)).rgb * 0.12 +
      sample_input(uv - vec2(0.0, pixel.y * 2.0)).rgb * 0.12 +
      soft * 0.52;
  vec3 texture_boost = sharpened + (sharpened - wide_soft) * 0.22 * strength;

  vec3 result = mix(source.rgb, texture_boost, strength);
  result = pow(clamp(result, 0.0, 1.0), vec3(0.98 - 0.05 * strength));

  frag_color = vec4(clamp(result, 0.0, 1.0), source.a);
}
