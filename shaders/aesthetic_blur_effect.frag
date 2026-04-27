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

float edge_strength(vec2 uv, vec2 pixel) {
  float left = luminance(sample_input(uv - vec2(pixel.x, 0.0)).rgb);
  float right = luminance(sample_input(uv + vec2(pixel.x, 0.0)).rgb);
  float up = luminance(sample_input(uv - vec2(0.0, pixel.y)).rgb);
  float down = luminance(sample_input(uv + vec2(0.0, pixel.y)).rgb);
  return length(vec2(right - left, down - up));
}

vec3 gaussian_blur(vec2 uv, vec2 pixel, float radius) {
  vec2 x = vec2(pixel.x * radius, 0.0);
  vec2 y = vec2(0.0, pixel.y * radius);

  vec3 color = sample_input(uv).rgb * 0.28;
  color += sample_input(uv + x).rgb * 0.16;
  color += sample_input(uv - x).rgb * 0.16;
  color += sample_input(uv + y).rgb * 0.16;
  color += sample_input(uv - y).rgb * 0.16;
  color += sample_input(uv + x + y).rgb * 0.06;
  color += sample_input(uv - x + y).rgb * 0.06;
  color += sample_input(uv + x - y).rgb * 0.06;
  color += sample_input(uv - x - y).rgb * 0.06;
  return color;
}

vec3 bilateral_skin_smooth(vec2 uv, vec2 pixel, vec3 source) {
  vec3 accum = source * 0.32;
  float total = 0.32;

  for (int i = 0; i < 4; i++) {
    vec2 offset = vec2(
      i < 2 ? -pixel.x * 1.5 : pixel.x * 1.5,
      mod(float(i), 2.0) < 0.5 ? -pixel.y * 1.5 : pixel.y * 1.5
    );
    vec3 sample_color = sample_input(uv + offset).rgb;
    float weight = exp(-dot(sample_color - source, sample_color - source) * 18.0);
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

  vec2 centered = (uv - 0.5) * vec2(0.92, 1.18);
  float center_mask = 1.0 - smoothstep(0.16, 0.60, length(centered));
  float detail_mask = smoothstep(0.05, 0.22, edge_strength(uv, pixel));
  float subject_mask = clamp(center_mask + detail_mask * 0.55, 0.0, 1.0);
  subject_mask = smoothstep(0.18, 0.82, subject_mask);

  vec3 blurred_background = gaussian_blur(uv, pixel, 2.0 + 5.5 * strength);
  vec3 smooth_subject = bilateral_skin_smooth(uv, pixel, source.rgb);
  smooth_subject = mix(source.rgb, smooth_subject, 0.48 * strength * subject_mask);
  smooth_subject = mix(smooth_subject, source.rgb, detail_mask * 0.35);

  vec3 result = mix(blurred_background, smooth_subject, subject_mask);
  result += vec3(0.08 * strength);

  frag_color = vec4(clamp(result, 0.0, 1.0), source.a);
}
