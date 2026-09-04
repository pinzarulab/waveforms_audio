import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum VoiceVisualizerKind {
  orb,
  wave,
  bars,
  upwardBars,
  voiceBars,
  halo,
  mirrorSpectrum,
  ribbon,
  liquidOrb,
  pulseRings,
  dotSpectrum,
  capsuleBars,
  voiceBloom,
  minimalLine,
}

enum VoiceVisualizerDirection { up, down, both, radial }

/// Immutable visual configuration shared by reactive and voice-chat widgets.
///
/// An empty [colors] list lets the widget select its default palette. A null
/// [inactiveColor] keeps the active palette during silence.
class VoiceVisualizerStyle {
  final VoiceVisualizerKind kind;
  final List<Color> colors;
  final Color? inactiveColor;
  final int barCount;
  final double spacing;
  final double cornerRadius;
  final double glow;
  final double density;
  final bool symmetric;
  final VoiceVisualizerDirection direction;

  const VoiceVisualizerStyle({
    this.kind = VoiceVisualizerKind.orb,
    this.colors = const [],
    this.inactiveColor,
    this.barCount = 32,
    this.spacing = 3,
    this.cornerRadius = 8,
    this.glow = 0.25,
    this.density = 1,
    this.symmetric = true,
    this.direction = VoiceVisualizerDirection.both,
  }) : assert(barCount >= 3 && barCount <= 128),
       assert(spacing >= 0),
       assert(cornerRadius >= 0),
       assert(glow >= 0 && glow <= 1),
       assert(density > 0 && density <= 3);

  const VoiceVisualizerStyle.orb({
    this.colors = const [],
    this.inactiveColor,
    this.glow = 0.3,
    this.density = 1,
    this.symmetric = true,
  }) : kind = VoiceVisualizerKind.orb,
       barCount = 32,
       spacing = 3,
       cornerRadius = 8,
       direction = VoiceVisualizerDirection.radial,
       assert(glow >= 0 && glow <= 1),
       assert(density > 0 && density <= 3);

  const VoiceVisualizerStyle.wave({
    this.colors = const [],
    this.inactiveColor,
    this.glow = 0.2,
    this.density = 1,
    this.symmetric = true,
    this.direction = VoiceVisualizerDirection.both,
  }) : kind = VoiceVisualizerKind.wave,
       barCount = 32,
       spacing = 3,
       cornerRadius = 8,
       assert(glow >= 0 && glow <= 1),
       assert(density > 0 && density <= 3);

  const VoiceVisualizerStyle.bars({
    this.colors = const [],
    this.inactiveColor,
    this.barCount = 24,
    this.spacing = 3,
    this.cornerRadius = 8,
    this.glow = 0.2,
    this.density = 1,
    this.symmetric = false,
    this.direction = VoiceVisualizerDirection.both,
  }) : kind = VoiceVisualizerKind.bars,
       assert(barCount >= 3 && barCount <= 128),
       assert(spacing >= 0),
       assert(cornerRadius >= 0),
       assert(glow >= 0 && glow <= 1),
       assert(density > 0 && density <= 3);

  const VoiceVisualizerStyle.upwardBars({
    this.colors = const [],
    this.inactiveColor,
    this.barCount = 24,
    this.spacing = 3,
    this.cornerRadius = 8,
    this.glow = 0.2,
    this.density = 1,
    this.symmetric = false,
    this.direction = VoiceVisualizerDirection.up,
  }) : kind = VoiceVisualizerKind.upwardBars,
       assert(barCount >= 3 && barCount <= 128),
       assert(spacing >= 0),
       assert(cornerRadius >= 0),
       assert(glow >= 0 && glow <= 1),
       assert(density > 0 && density <= 3);

  const VoiceVisualizerStyle.voiceBars({
    this.colors = const [],
    this.inactiveColor,
    this.barCount = 5,
    this.spacing = 5,
    this.cornerRadius = 12,
    this.glow = 0.25,
    this.density = 1,
    this.symmetric = true,
    this.direction = VoiceVisualizerDirection.both,
  }) : kind = VoiceVisualizerKind.voiceBars,
       assert(barCount >= 3 && barCount <= 128),
       assert(spacing >= 0),
       assert(cornerRadius >= 0),
       assert(glow >= 0 && glow <= 1),
       assert(density > 0 && density <= 3);

  const VoiceVisualizerStyle.halo({
    this.colors = const [],
    this.inactiveColor,
    this.barCount = 64,
    this.spacing = 2,
    this.cornerRadius = 8,
    this.glow = 0.3,
    this.density = 1,
    this.symmetric = true,
    this.direction = VoiceVisualizerDirection.radial,
  }) : kind = VoiceVisualizerKind.halo,
       assert(barCount >= 3 && barCount <= 128),
       assert(spacing >= 0),
       assert(cornerRadius >= 0),
       assert(glow >= 0 && glow <= 1),
       assert(density > 0 && density <= 3);

  const VoiceVisualizerStyle.mirrorSpectrum({
    this.colors = const [],
    this.inactiveColor,
    this.barCount = 32,
    this.spacing = 3,
    this.cornerRadius = 8,
    this.glow = 0.22,
    this.density = 1,
    this.symmetric = true,
    this.direction = VoiceVisualizerDirection.both,
  }) : kind = VoiceVisualizerKind.mirrorSpectrum,
       assert(barCount >= 3 && barCount <= 128),
       assert(spacing >= 0),
       assert(cornerRadius >= 0),
       assert(glow >= 0 && glow <= 1),
       assert(density > 0 && density <= 3);

  const VoiceVisualizerStyle.ribbon({
    this.colors = const [],
    this.inactiveColor,
    this.glow = 0.28,
    this.density = 1,
    this.symmetric = true,
    this.direction = VoiceVisualizerDirection.both,
  }) : kind = VoiceVisualizerKind.ribbon,
       barCount = 32,
       spacing = 3,
       cornerRadius = 8,
       assert(glow >= 0 && glow <= 1),
       assert(density > 0 && density <= 3);

  const VoiceVisualizerStyle.liquidOrb({
    this.colors = const [],
    this.inactiveColor,
    this.glow = 0.45,
    this.density = 1.2,
    this.symmetric = true,
  }) : kind = VoiceVisualizerKind.liquidOrb,
       barCount = 48,
       spacing = 2,
       cornerRadius = 8,
       direction = VoiceVisualizerDirection.radial,
       assert(glow >= 0 && glow <= 1),
       assert(density > 0 && density <= 3);

  const VoiceVisualizerStyle.pulseRings({
    this.colors = const [],
    this.inactiveColor,
    this.glow = 0.35,
    this.density = 1,
    this.symmetric = true,
  }) : kind = VoiceVisualizerKind.pulseRings,
       barCount = 5,
       spacing = 4,
       cornerRadius = 8,
       direction = VoiceVisualizerDirection.radial,
       assert(glow >= 0 && glow <= 1),
       assert(density > 0 && density <= 3);

  const VoiceVisualizerStyle.dotSpectrum({
    this.colors = const [],
    this.inactiveColor,
    this.barCount = 28,
    this.spacing = 5,
    this.glow = 0.35,
    this.density = 1,
    this.symmetric = false,
    this.direction = VoiceVisualizerDirection.up,
  }) : kind = VoiceVisualizerKind.dotSpectrum,
       cornerRadius = 8,
       assert(barCount >= 3 && barCount <= 128),
       assert(spacing >= 0),
       assert(glow >= 0 && glow <= 1),
       assert(density > 0 && density <= 3);

  const VoiceVisualizerStyle.capsuleBars({
    this.colors = const [],
    this.inactiveColor,
    this.barCount = 20,
    this.spacing = 4,
    this.cornerRadius = 99,
    this.glow = 0.18,
    this.density = 1,
    this.symmetric = false,
    this.direction = VoiceVisualizerDirection.up,
  }) : kind = VoiceVisualizerKind.capsuleBars,
       assert(barCount >= 3 && barCount <= 128),
       assert(spacing >= 0),
       assert(cornerRadius >= 0),
       assert(glow >= 0 && glow <= 1),
       assert(density > 0 && density <= 3);

  const VoiceVisualizerStyle.voiceBloom({
    this.colors = const [],
    this.inactiveColor,
    this.barCount = 24,
    this.spacing = 2,
    this.glow = 0.48,
    this.density = 1,
    this.symmetric = true,
    this.direction = VoiceVisualizerDirection.radial,
  }) : kind = VoiceVisualizerKind.voiceBloom,
       cornerRadius = 12,
       assert(barCount >= 3 && barCount <= 128),
       assert(spacing >= 0),
       assert(glow >= 0 && glow <= 1),
       assert(density > 0 && density <= 3);

  const VoiceVisualizerStyle.minimalLine({
    this.colors = const [],
    this.inactiveColor,
    this.glow = 0.12,
    this.density = 1,
    this.symmetric = false,
    this.direction = VoiceVisualizerDirection.both,
  }) : kind = VoiceVisualizerKind.minimalLine,
       barCount = 32,
       spacing = 3,
       cornerRadius = 8,
       assert(glow >= 0 && glow <= 1),
       assert(density > 0 && density <= 3);

  VoiceVisualizerStyle copyWith({
    VoiceVisualizerKind? kind,
    List<Color>? colors,
    Color? inactiveColor,
    bool clearInactiveColor = false,
    int? barCount,
    double? spacing,
    double? cornerRadius,
    double? glow,
    double? density,
    bool? symmetric,
    VoiceVisualizerDirection? direction,
  }) => VoiceVisualizerStyle(
    kind: kind ?? this.kind,
    colors: colors ?? this.colors,
    inactiveColor: clearInactiveColor
        ? null
        : inactiveColor ?? this.inactiveColor,
    barCount: barCount ?? this.barCount,
    spacing: spacing ?? this.spacing,
    cornerRadius: cornerRadius ?? this.cornerRadius,
    glow: glow ?? this.glow,
    density: density ?? this.density,
    symmetric: symmetric ?? this.symmetric,
    direction: direction ?? this.direction,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceVisualizerStyle &&
          kind == other.kind &&
          listEquals(colors, other.colors) &&
          inactiveColor == other.inactiveColor &&
          barCount == other.barCount &&
          spacing == other.spacing &&
          cornerRadius == other.cornerRadius &&
          glow == other.glow &&
          density == other.density &&
          symmetric == other.symmetric &&
          direction == other.direction;

  @override
  int get hashCode => Object.hash(
    kind,
    Object.hashAll(colors),
    inactiveColor,
    barCount,
    spacing,
    cornerRadius,
    glow,
    density,
    symmetric,
    direction,
  );
}
