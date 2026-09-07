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
uniform float uBarCount;
uniform vec4 uColor1;
uniform vec4 uColor2;
uniform float uColorCount;

out vec4 fragColor;

const float PI = 3.141592653589793;
const float TAU = 6.283185307179586;

float saturate(float value) {
  return clamp(value, 0.0, 1.0);
}

float angleOf(vec2 point) {
  if (dot(point, point) < 0.00000001) return 0.0;
  return atan(point.y, point.x);
}

float radialBandPosition(float angle) {
  return (1.0 - cos(angle)) * 0.5;
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

float fluidBand(float position) {
  float total = 0.0;
  float weight = 0.0;
  for (int i = 0; i < 8; i++) {
    float x = float(i) / 7.0;
    float d = (position - x) / 0.22;
    float w = exp(-d * d * 2.0);
    total += bandAt(x) * w;
    weight += w;
  }
  return total / weight;
}

float fluidSource(float position) {
  return mix(position, (1.0 + cos(position * TAU)) * 0.5, uSymmetric);
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

// Evenly spaced stops, matching Canvas _activeColor interpolation.
vec4 gradientColor(float position) {
  float p = saturate(position) * (uColorCount - 1.0);
  if (uColorCount < 1.5) return uPrimaryColor;
  if (p <= 1.0) return mix(uPrimaryColor, uColor1, p);
  if (p <= 2.0) return mix(uColor1, uColor2, p - 1.0);
  return mix(uColor2, uSecondaryColor, p - 2.0);
}

vec3 palette(float position, float activation) {
  vec3 activePalette = gradientColor(position).rgb;
  vec3 resting = mix(activePalette, uInactiveColor.rgb, uHasInactiveColor);
  return mix(resting, activePalette, activation);
}

vec4 finish(vec3 color, float alpha) {
  float a = saturate(alpha);
  return vec4(clamp(color, 0.0, 1.0) * a, a);
}

float liquidMembrane(vec2 point, float radius, float layer, float motion) {
  float angle = angleOf(point);
  float detail = max(0.55, uDensity);
  float local = bandAt(radialBandPosition(angle));
  float deformation =
      sin(angle * 3.0 + uTime * 1.6 + layer) * uMids * 0.065 +
      sin(angle * (4.0 + detail) - uTime * 2.1 + layer * 0.7) *
          (uTreble * 0.024 + local * 0.032 + uVoiceActivity * 0.018) +
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
  // Avoid polar color gradients inside the fill: their undefined origin
  // produces a visible spoke at the center of the orb.
  float drift = sin(uTime * 0.22) * 0.04 * motion;
  float shift = saturate(
      0.5 - point.y * 1.65 + point.x * 0.25 + drift);
  vec3 color = palette(shift, activation);
  vec2 lightDelta = point - vec2(-0.075, -0.105);
  float highlight = exp(-dot(lightDelta, lightDelta) * 34.0);
  color = mix(color, vec3(1.0), highlight * fill * 0.18);
  float membranes = edge1 * 0.20 + edge2 * 0.15 + edge3 * 0.11;
  float alpha = fill * gradientColor(shift).a +
      edge0 * 0.42 + membranes + glow;
  vec3 rgb = color * (fill + edge0 * 0.30) +
      palette(0.0, activation) * glow + palette(1.0, activation) * membranes;
  return finish(rgb / max(alpha, 0.0001), alpha);
}

vec4 orb(vec2 point, float unit, float activity, float breathing,
         float activation, float motion) {
  float angle = angleOf(point);
  float position = fract((angle + PI) / TAU);
  float energy = bandAt(radialBandPosition(angle));
  float radius = 0.23 + breathing * 0.025 +
      energy * 0.055 + uBass * 0.018 +
      sin(angle * (5.0 + uDensity * 2.0) - uTime * 1.8) *
          uTreble * 0.012 * motion;
  float d = length(point) - radius;
  float aa = max(1.25 / unit, 0.0012);
  float fill = 1.0 - smoothstep(-aa, aa, d);
  float edge = lineMask(d, aa * 1.2, aa * 2.0);
  float glow = glowMask(max(d, 0.0), 0.08 + activity * 0.32, 24.0);
  float colorShift = saturate(
      0.5 - point.y * 1.65 + point.x * 0.25 +
      sin(uTime * 0.22) * 0.04 * motion);
  vec3 color = palette(colorShift, activation);
  vec2 lightDelta = point - vec2(-0.075, -0.105);
  float highlight = exp(-dot(lightDelta, lightDelta) * 34.0) * fill;
  color = mix(color, vec3(1.0), highlight * 0.18);
  float alpha = fill * 0.90 + edge * 0.32 + glow;
  return finish(color, alpha);
}

vec4 waves(vec2 uv, float activity, float activation, float motion,
           float breathing, bool ribbonMode) {
  float aa = max(1.0 / max(uSize.y, 1.0), 0.0012);
  float y = uv.y - 0.5;
  float sharp = 0.0;
  float glow = 0.0;
  vec3 rgb = vec3(0.0);
  float weight = 0.0;
  for (int i = 0; i < 5; i++) {
    float layer = float(i);
    float rawEnergy = fluidBand(fluidSource(uv.x));
    float idle = breathing *
        (0.78 + 0.22 * sin(uv.x * PI * 5.0 + uTime));
    float energy = max(rawEnergy, idle);
    float field;
    float mirrorField;
    float prominence;
    if (ribbonMode) {
      float carrier = sin(uv.x * PI * (1.6 + layer * 0.2) -
          uTime * (1.2 + layer * 0.08)) * motion;
      field = carrier * (8.0 / max(uSize.y, 1.0) + energy * 0.22) +
          (layer - 2.0) * 3.0 / max(uSize.y, 1.0);
      mirrorField = field;
      prominence = 0.22 + (4.0 - layer) * 0.14;
    } else {
      if (i >= 4) continue;
      float taper = pow(max(0.0, sin(uv.x * PI)), 1.5);
      float carrier = sin(uv.x * PI * (2.0 + layer * 0.35) -
          uTime * 2.0 + layer) * energy * motion;
      float displacement =
          (energy * 0.24 + carrier * 0.12) * taper;
      field = uDirection > 0.5 && uDirection < 1.5
          ? displacement
          : -displacement;
      mirrorField = -field;
      prominence = i == 0 ? 0.9 : 0.24;
    }
    float distance = y - field;
    float width = aa * (ribbonMode
        ? 1.15 + (4.0 - layer) * 0.32
        : 1.35 + (4.0 - layer) * 0.18);
    float line = lineMask(distance, width, aa * 1.5) * prominence;
    bool mirrored = !ribbonMode &&
        (uSymmetric > 0.5 || uDirection > 1.5);
    if (mirrored) {
      line += lineMask(y - mirrorField, aa * 1.2, aa * 1.5) * 0.22;
    }
    float haze = glowMask(distance, (0.025 + activity * 0.07) * prominence,
        ribbonMode ? 58.0 : 46.0);
    if (mirrored) {
      haze += glowMask(y - mirrorField, 0.015 + activity * 0.025, 46.0);
    }
    vec3 color = palette(layer / (ribbonMode ? 4.0 : 3.0), activation);
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
  float angle = angleOf(point);
  float radius = length(point);
  float count = clamp(floor(uBarCount * uDensity + 0.5), 12.0, 192.0);
  float sector = TAU / count;
  float localAngle = mod(angle + PI * 0.5 + sector * 0.5, sector) - sector * 0.5;
  float rayAngle = angle - localAngle;
  float energy = max(fluidBand(radialBandPosition(rayAngle)), breathing);
  float inner = 0.25 + uBass * 0.02;
  float rayLength = 0.012 + energy * 0.09;
  float halfWidth = min(0.014, inner * TAU / count * 0.55) * 0.5;
  // Distance to a radial capsule gives both ends the same soft round cap.
  float radial = radius * cos(localAngle) - inner;
  float tangent = radius * sin(localAngle);
  float d = length(vec2(tangent, radial - clamp(radial, 0.0, rayLength))) - halfWidth;
  float aa = max(0.8 / unit, 0.0008);
  float ray = 1.0 - smoothstep(-aa, aa, d);
  float ring = lineMask(radius - (inner - 0.018), 0.002, aa) * 0.33;
  float glow = exp(-max(d, 0.0) * 90.0) * uGlow * 0.18;
  return finish(palette(point.x / 0.76 + 0.5, activation), ray + ring + glow);
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
  float angle = angleOf(point);
  float energy = saturate(fluidBand(radialBandPosition(angle)) * 0.75 +
      uVoiceActivity * 0.25);
  float count = clamp(floor(uBarCount * uDensity + 0.5), 6.0, 12.0);
  float lobe = (1.0 + cos((angle + PI * 0.5) * count)) * 0.5;
  float radius = 0.19 + energy * 0.035 + lobe * (0.014 + energy * 0.035);
  float d = length(point) - radius;
  float aa = max(0.8 / min(uSize.x, uSize.y), 0.0008);
  float fill = 1.0 - smoothstep(-aa, aa, d);
  float edge = lineMask(d, 0.0015, aa) * 0.25;
  float glow = exp(-max(d, 0.0) * 38.0) * uGlow * 0.25;
  vec3 color = palette(point.x / 0.60 + 0.5, activation);
  vec2 lightDelta = point - vec2(-0.07, -0.09);
  float highlight = exp(-dot(lightDelta, lightDelta) * 65.0) * 0.22;
  color = mix(color, vec3(1.0), (highlight + edge * 0.3) * fill);
  return finish(color, fill + edge + glow);
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
    fragColor = waves(uv, activity, activation, motion, breathing, false);
  } else if (uStyleMode < 2.5) {
    fragColor = halo(point, unit, activity, breathing, activation, motion);
  } else if (uStyleMode < 3.5) {
    fragColor = waves(uv, activity, activation, motion, breathing, true);
  } else if (uStyleMode < 4.5) {
    fragColor = liquidOrb(point, unit, activity, breathing, activation, motion);
  } else if (uStyleMode < 5.5) {
    fragColor = pulseRings(point, unit, activity, activation, motion);
  } else {
    fragColor = bloom(point, activity, activation, motion);
  }
}
