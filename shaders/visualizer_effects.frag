#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
uniform float uTime;
uniform float uBass;
uniform float uMids;
uniform float uTreble;
uniform float uLevel;
uniform float uPeak;
uniform float uVoiceActivity;
uniform float uIdleBreathing;
uniform vec4 uPrimaryColor;
uniform vec4 uSecondaryColor;
uniform vec4 uInactiveColor;
uniform float uHasInactiveColor;
uniform float uGlow;
uniform float uDensity;
uniform float uReducedMotion;
uniform float uStyleMode;
uniform float uSymmetric;
uniform float uDirection;
uniform float uBand0;
uniform float uBand1;
uniform float uBand2;
uniform float uBand3;
uniform float uBand4;
uniform float uBand5;
uniform float uBand6;
uniform float uBand7;

out vec4 fragColor;

const float PI = 3.141592653589793;
const float TAU = 6.283185307179586;

float saturate(float value) {
  return clamp(value, 0.0, 1.0);
}

float bandAt(float position) {
  float p = saturate(position) * 7.0;
  if (p < 1.0) return mix(uBand0, uBand1, p);
  if (p < 2.0) return mix(uBand1, uBand2, p - 1.0);
  if (p < 3.0) return mix(uBand2, uBand3, p - 2.0);
  if (p < 4.0) return mix(uBand3, uBand4, p - 3.0);
  if (p < 5.0) return mix(uBand4, uBand5, p - 4.0);
  if (p < 6.0) return mix(uBand5, uBand6, p - 5.0);
  return mix(uBand6, uBand7, p - 6.0);
}

float sourcePosition(float position) {
  return mix(position, abs(position - 0.5) * 2.0, uSymmetric);
}

float lineMask(float distance, float width, float aa) {
  return 1.0 - smoothstep(width, width + aa, abs(distance));
}

float glowMask(float distance, float strength, float scale) {
  return exp(-abs(distance) * scale) * uGlow * strength;
}

vec3 palette(float position, float activation) {
  vec3 activePalette = mix(
      uPrimaryColor.rgb, uSecondaryColor.rgb, saturate(position));
  vec3 resting = mix(activePalette, uInactiveColor.rgb, uHasInactiveColor);
  return mix(resting, activePalette, activation);
}

vec4 finish(vec3 color, float alpha) {
  float a = saturate(alpha);
  return vec4(clamp(color, 0.0, 1.0) * a, a);
}

float liquidMembrane(vec2 point, float radius, float layer, float motion) {
  float angle = atan(point.y, point.x);
  float detail = max(0.55, uDensity);
  float deformation =
      sin(angle * 3.0 + uTime * 1.6 + layer) * uMids * 0.065 +
      sin(angle * (4.0 + detail) - uTime * 2.1 + layer * 0.7) *
          (uTreble * 0.048 + uVoiceActivity * 0.018) +
      sin(angle * 2.0 - uTime + layer * 0.35) * uBass * 0.042;
  return length(point) - radius * (1.0 + layer * 0.046 + deformation * motion);
}

vec4 liquidOrb(vec2 point, float unit, float activity, float breathing,
               float activation, float motion) {
  float visible = max(activity, breathing);
  float radius = 0.21 * (1.0 + uBass * 0.14 + breathing);
  float d0 = liquidMembrane(point, radius, 0.0, motion);
  float d1 = liquidMembrane(point, radius, 1.0, motion);
  float d2 = liquidMembrane(point, radius, 2.0, motion);
  float d3 = liquidMembrane(point, radius, 3.0, motion);
  float aa = max(1.25 / unit, 0.0012);
  float fill = 1.0 - smoothstep(-aa, aa, d0);
  float edge0 = lineMask(d0, aa, aa * 2.5);
  float edge1 = lineMask(d1, aa, aa * 2.0);
  float edge2 = lineMask(d2, aa, aa * 2.0);
  float edge3 = lineMask(d3, aa, aa * 2.0);
  float glow = exp(-max(d3, 0.0) * 18.0) *
      uGlow * (0.10 + visible * 0.32);
  float angle = atan(point.y, point.x);
  float shift = 0.5 + 0.5 * sin(angle + uTime * 0.22 * motion);
  vec3 color = palette(shift, activation);
  vec2 normal = normalize(point + vec2(0.0001));
  float highlight = pow(max(0.0, dot(normal, normalize(vec2(-0.55, -0.82)))), 4.0);
  color = mix(color, vec3(1.0), highlight * fill * 0.30);
  float membranes = edge1 * 0.20 + edge2 * 0.15 + edge3 * 0.11;
  float alpha = fill * mix(uPrimaryColor.a, uSecondaryColor.a, shift) +
      edge0 * 0.42 + membranes + glow;
  vec3 rgb = color * (fill + edge0 * 0.30) +
      uPrimaryColor.rgb * glow + uSecondaryColor.rgb * membranes;
  return finish(rgb / max(alpha, 0.0001), alpha);
}

vec4 orb(vec2 point, float unit, float activity, float breathing,
         float activation, float motion) {
  float angle = atan(point.y, point.x);
  float position = fract((angle + PI) / TAU);
  float energy = bandAt(sourcePosition(position));
  float radius = 0.195 + breathing * 0.025 +
      energy * 0.055 + uBass * 0.018 +
      sin(angle * (5.0 + uDensity * 2.0) - uTime * 1.8) *
          uTreble * 0.012 * motion;
  float d = length(point) - radius;
  float aa = max(1.25 / unit, 0.0012);
  float fill = 1.0 - smoothstep(-aa, aa, d);
  float edge = lineMask(d, aa * 1.2, aa * 2.0);
  float glow = glowMask(max(d, 0.0), 0.08 + activity * 0.32, 24.0);
  vec3 color = palette(position, activation);
  float highlight = pow(max(0.0, dot(normalize(point + vec2(0.0001)),
      normalize(vec2(-0.5, -0.85)))), 5.0) * fill;
  color = mix(color, vec3(1.0), highlight * 0.26);
  float alpha = fill * 0.90 + edge * 0.32 + glow;
  return finish(color, alpha);
}

float waveY(float x, float layer, float motion) {
  float energy = bandAt(sourcePosition(x));
  float carrier = sin(x * PI * (3.4 + layer * 0.52) -
      uTime * (1.6 + layer * 0.13));
  float amplitude = (0.018 + energy * (0.10 + layer * 0.012)) * motion;
  float direction = uDirection < 0.5 ? -1.0 :
      (uDirection < 1.5 ? 1.0 : carrier);
  return direction * amplitude * (uDirection < 1.5 ? abs(carrier) : 1.0);
}

vec4 waves(vec2 uv, float activity, float activation, float motion,
           bool ribbonMode) {
  float aa = max(1.0 / max(uSize.y, 1.0), 0.0012);
  float y = uv.y - 0.5;
  float sharp = 0.0;
  float glow = 0.0;
  vec3 rgb = vec3(0.0);
  float weight = 0.0;
  for (int i = 0; i < 5; i++) {
    float layer = float(i);
    float offset = ribbonMode ? (layer - 2.0) * 0.012 : (layer - 2.0) * 0.006;
    float field = waveY(uv.x, layer, motion) + offset;
    float distance = y - field;
    float prominence = ribbonMode ? (1.0 - layer * 0.11) :
        (i < 3 ? 1.0 - layer * 0.18 : 0.0);
    float width = aa * (ribbonMode ? 1.15 + (4.0 - layer) * 0.32 : 1.5);
    float line = lineMask(distance, width, aa * 1.5) * prominence;
    float haze = glowMask(distance, (0.035 + activity * 0.09) * prominence,
        ribbonMode ? 52.0 : 38.0);
    vec3 color = palette(layer / 4.0, activation);
    rgb += color * (line + haze);
    sharp += line;
    glow += haze;
    weight += line + haze;
  }
  float alpha = saturate(sharp * 0.82 + glow);
  return finish(rgb / max(weight, 0.0001), alpha);
}

vec4 halo(vec2 point, float unit, float activity, float breathing,
          float activation, float motion) {
  float angle = atan(point.y, point.x);
  float position = fract((angle + PI) / TAU);
  float energy = bandAt(sourcePosition(position));
  float radius = 0.205 + breathing * 0.02 + energy * 0.038 +
      sin(angle * 4.0 - uTime * 1.5) * uMids * 0.008 * motion;
  float d = length(point) - radius;
  float aa = max(1.25 / unit, 0.0012);
  float ring = lineMask(d, aa * (1.8 + activity * 2.0), aa * 2.0);
  float glow = glowMask(d, 0.06 + activity * 0.28, 27.0);
  return finish(palette(position, activation), ring * 0.92 + glow);
}

vec4 pulseRings(vec2 point, float unit, float activity, float activation,
                float motion) {
  float radius = length(point);
  float aa = max(1.25 / unit, 0.0012);
  float alpha = 0.0;
  vec3 rgb = vec3(0.0);
  float weight = 0.0;
  for (int i = 0; i < 7; i++) {
    float progress = motion > 0.5
        ? fract(uTime * 0.22 + float(i) / 7.0)
        : float(i) / 7.0;
    float ringRadius = 0.09 + progress * 0.34;
    float fade = (1.0 - progress) * (0.14 + activity * 0.72);
    float line = lineMask(radius - ringRadius,
        aa * (1.0 + activity * 2.1), aa * 2.0) * fade;
    float haze = glowMask(radius - ringRadius, fade * 0.07, 42.0);
    vec3 color = palette(progress, activation);
    rgb += color * (line + haze);
    alpha += line + haze;
    weight += line + haze;
  }
  float core = 1.0 - smoothstep(0.065, 0.068 + aa, radius);
  rgb += palette(0.35, activation) * core;
  alpha += core;
  weight += core;
  return finish(rgb / max(weight, 0.0001), alpha);
}

vec4 bloom(vec2 point, float activity, float activation, float motion) {
  float radius = length(point);
  float angle = atan(point.y, point.x);
  float position = fract((angle + PI) / TAU);
  float energy = bandAt(sourcePosition(position));
  float petals = pow(abs(cos(angle * (8.0 + floor(uDensity * 4.0)))), 5.0);
  float petalRadius = 0.145 + petals *
      (0.045 + energy * 0.105 + uVoiceActivity * 0.025) *
      (0.88 + 0.12 * sin(uTime * 1.7 + angle * 2.0) * motion);
  float aa = max(1.25 / min(uSize.x, uSize.y), 0.0012);
  float shape = 1.0 - smoothstep(petalRadius - aa, petalRadius + aa, radius);
  float core = 1.0 - smoothstep(0.115, 0.12 + aa, radius);
  float edge = lineMask(radius - petalRadius, aa * 1.2, aa * 2.0);
  float glow = glowMask(max(radius - petalRadius, 0.0),
      0.08 + activity * 0.28, 26.0);
  vec3 color = palette(position, activation);
  vec3 coreColor = mix(palette(0.0, activation), palette(1.0, activation),
      smoothstep(0.0, 0.12, radius));
  color = mix(color, coreColor, core);
  return finish(color, shape * 0.88 + core * 0.25 + edge * 0.28 + glow);
}

void main() {
  vec2 coordinate = FlutterFragCoord().xy;
  float unit = max(1.0, min(uSize.x, uSize.y));
  vec2 point = (coordinate - uSize * 0.5) / unit;
  vec2 uv = coordinate / max(uSize, vec2(1.0));
  float activity = max(max(uLevel, uPeak),
      max(max(uBass, uMids), max(uTreble, uVoiceActivity)));
  float motion = 1.0 - step(0.5, uReducedMotion);
  float breathing = uIdleBreathing *
      (0.72 + sin(uTime * TAU) * 0.28) * motion;
  float activation = smoothstep(0.0, 0.24, max(activity, breathing));

  if (uStyleMode < 0.5) {
    fragColor = orb(point, unit, activity, breathing, activation, motion);
  } else if (uStyleMode < 1.5) {
    fragColor = waves(uv, activity, activation, motion, false);
  } else if (uStyleMode < 2.5) {
    fragColor = halo(point, unit, activity, breathing, activation, motion);
  } else if (uStyleMode < 3.5) {
    fragColor = waves(uv, activity, activation, motion, true);
  } else if (uStyleMode < 4.5) {
    fragColor = liquidOrb(point, unit, activity, breathing, activation, motion);
  } else if (uStyleMode < 5.5) {
    fragColor = pulseRings(point, unit, activity, activation, motion);
  } else {
    fragColor = bloom(point, activity, activation, motion);
  }
}
