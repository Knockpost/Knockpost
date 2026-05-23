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

vec3 spatial_denoise(vec2 uv, vec2 pixel) {
  vec3 center = sample_input(uv).rgb;
  vec3 accum = center * 0.32;
  float total = 0.32;

  vec2 offsets[8] = vec2[](
    vec2(pixel.x, 0.0),
    vec2(-pixel.x, 0.0),
    vec2(0.0, pixel.y),
    vec2(0.0, -pixel.y),
    vec2(pixel.x, pixel.y),
    vec2(-pixel.x, pixel.y),
    vec2(pixel.x, -pixel.y),
    vec2(-pixel.x, -pixel.y)
  );

  for (int i = 0; i < 8; i++) {
    vec3 sample_color = sample_input(uv + offsets[i]).rgb;
    float similarity = exp(-dot(sample_color - center, sample_color - center) * 24.0);
    float weight = mix(0.06, 0.12, similarity);
    accum += sample_color * weight;
    total += weight;
  }

  return accum / max(total, 0.0001);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;
  vec2 pixel = 1.0 / max(u_size, vec2(1.0));
  float strength = clamp(u_intensity, 0.0, 1.0);
  vec4 source = sample_input(uv);
  float source_luma = luminance(source.rgb);
  float shadow_mask = 1.0 - smoothstep(0.20, 0.76, source_luma);

  vec3 denoised = spatial_denoise(uv, pixel);
  vec3 cleaned = mix(source.rgb, denoised, (0.22 + 0.42 * shadow_mask) * strength);

  vec3 lifted = cleaned * (1.0 + 0.45 * strength + 0.28 * shadow_mask * strength);
  lifted = 1.0 - exp(-lifted * (1.0 + 0.35 * strength));

  vec3 local_blur =
      sample_input(uv).rgb * 0.4 +
      sample_input(uv + vec2(pixel.x, 0.0)).rgb * 0.15 +
      sample_input(uv - vec2(pixel.x, 0.0)).rgb * 0.15 +
      sample_input(uv + vec2(0.0, pixel.y)).rgb * 0.15 +
      sample_input(uv - vec2(0.0, pixel.y)).rgb * 0.15;

  vec3 detail = lifted - local_blur;
  vec3 sharpened = lifted + detail * (0.28 + 0.44 * strength);

  float final_luma = luminance(sharpened);
  vec3 color_ratio = source.rgb / max(source_luma, 0.05);
  vec3 color_preserved = color_ratio * final_luma;
  vec3 result = mix(sharpened, color_preserved, 0.20);
  result = result / (1.0 + max(max(result.r, result.g), result.b) * 0.18 * strength);

  frag_color = vec4(clamp(result, 0.0, 1.0), source.a);
}
