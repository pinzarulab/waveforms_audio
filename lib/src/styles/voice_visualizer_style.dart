import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Available reactive visual shapes. Select with a named style constructor
/// or the generic [VoiceVisualizerStyle] constructor.
enum VoiceVisualizerKind {
  /// Layered radial orb shaped by frequency energy.
  orb,

  /// Smooth layered waveform with optional mirrored curves.
  wave,

  /// Rounded frequency bars, centered by default.
  bars,

  /// Frequency bars rising from a lower baseline.
  upwardBars,

  /// Compact rounded bars with voice-focused emphasis.
  voiceBars,

  /// Rounded radial rays with a seamless spatial gradient.
  halo,

  /// Upper spectrum bars above a separated, fading reflection.
  mirrorSpectrum,

  /// Broad, smooth strands moving in layered waves.
  ribbon,

  /// Fluid orb membranes with a Canvas fallback.
  liquidOrb,

  /// Expanding rings with a central core.
  pulseRings,

  /// Frequency dots with faint trails to a baseline.
  dotSpectrum,

  /// Persistent tracks filled according to frequency energy.
  capsuleBars,

  /// Continuous rounded petals surrounding a gradient-filled bloom.
  voiceBloom,

  /// Compact waveform line for small controls.
  minimalLine,
}

/// Direction hints used by styles that support a baseline or radial layout.
/// Not every style uses every direction; see [VoiceVisualizerStyle.direction].
enum VoiceVisualizerDirection {
  /// Grow above a baseline where supported.
  up,

  /// Grow below a baseline where supported.
  down,

  /// Use both sides of a center line where supported.
  both,

  /// Use a radial layout in styles designed for it.
  radial,
}

/// Immutable visual configuration shared by reactive and voice-chat widgets.
///
/// An empty [colors] list lets the widget select its default palette. A null
/// [inactiveColor] keeps the active palette during silence.
class VoiceVisualizerStyle {
  /// Visual shape; defaults to [VoiceVisualizerKind.orb] in the generic constructor.
  final VoiceVisualizerKind kind;

  /// Evenly spaced active palette. Empty selects widget defaults; one color is solid.
  ///
  /// Canvas retains every stop. GPU supports up to four stops and falls back to
  /// Canvas for longer lists. Treat the supplied list as immutable after construction.
  final List<Color> colors;

  /// Optional resting color; null keeps the active palette during silence.
  /// When set, the renderer blends toward active colors as energy increases.
  final Color? inactiveColor;

  /// Base element count, 3–128; generic default 32.
  ///
  /// [density] scales this for count-based styles, with renderer-specific caps.
  /// Halo uses 12–192 rays; bloom uses 6–12 lobes. Fixed wave/ribbon layers and
  /// some shader effects do not use this value.
  final int barCount;

  /// Non-negative gap in logical pixels for bar-based layouts; generic default 3.
  /// May be reduced to fit available width. Not used by every radial/fluid style.
  final double spacing;

  /// Non-negative bar corner radius in logical pixels; generic default 8.
  /// Bar painters cap it at half the bar width; halo and bloom round their own geometry.
  final double cornerRadius;

  /// Glow strength from 0 to 1; generic default 0.25.
  /// Zero disables optional glow. Appearance and usage depend on the renderer/style.
  final double glow;

  /// Detail/count multiplier, greater than 0 and at most 3; generic default 1.
  /// Element counts are capped by each painter; this does not change FFT band count.
  final double density;

  /// Visual size multiplier inside the widget bounds; defaults to 1.
  ///
  /// Values below 1 add space around the style. Values above 1 enlarge it and
  /// clip any portion outside the widget. This does not change layout size.
  final double scale;

  /// Whether supported styles mirror frequency sampling toward the center.
  /// Generic default true; wave also draws reflected curves when enabled.
  final bool symmetric;

  /// Layout hint; generic default [VoiceVisualizerDirection.both].
  ///
  /// Bars, wave, dots, capsules, and minimal line interpret up/down/both. Orb,
  /// halo, bloom, and rings use radial geometry. Ribbon and mirror spectrum keep
  /// their own layouts. A direction unsupported by a style does not redesign it.
  final VoiceVisualizerDirection direction;

  /// Creates a style with access to every configuration field.
  ///
  /// Named constructors provide tuned defaults and expose only relevant options.
  /// Use [copyWith] to change fields not exposed by a named constructor.
  const VoiceVisualizerStyle({
    this.kind = VoiceVisualizerKind.orb,
    this.colors = const [],
    this.inactiveColor,
    this.barCount = 32,
    this.spacing = 3,
    this.cornerRadius = 8,
    this.glow = 0.25,
    this.density = 1,
    this.scale = 1,
    this.symmetric = true,
    this.direction = VoiceVisualizerDirection.both,
  })  : assert(barCount >= 3 && barCount <= 128),
        assert(spacing >= 0),
        assert(cornerRadius >= 0),
        assert(glow >= 0 && glow <= 1),
        assert(density > 0 && density <= 3),
        assert(scale > 0 && scale <= 4);

  /// Layered radial orb shaped by frequency energy.
  /// See the parameter defaults below; use [copyWith] for additional fields.
  const VoiceVisualizerStyle.orb({
    this.colors = const [],
    this.inactiveColor,
    this.glow = 0.3,
    this.density = 1,
    this.scale = 1,
    this.symmetric = true,
  })  : kind = VoiceVisualizerKind.orb,
        barCount = 32,
        spacing = 3,
        cornerRadius = 8,
        direction = VoiceVisualizerDirection.radial,
        assert(glow >= 0 && glow <= 1),
        assert(density > 0 && density <= 3),
        assert(scale > 0 && scale <= 4);

  /// Smooth layered waveform with optional mirrored curves.
  /// See the parameter defaults below; use [copyWith] for additional fields.
  const VoiceVisualizerStyle.wave({
    this.colors = const [],
    this.inactiveColor,
    this.glow = 0.2,
    this.density = 1,
    this.scale = 1,
    this.symmetric = true,
    this.direction = VoiceVisualizerDirection.both,
  })  : kind = VoiceVisualizerKind.wave,
        barCount = 32,
        spacing = 3,
        cornerRadius = 8,
        assert(glow >= 0 && glow <= 1),
        assert(density > 0 && density <= 3),
        assert(scale > 0 && scale <= 4);

  /// Rounded frequency bars, centered by default.
  /// See the parameter defaults below; use [copyWith] for additional fields.
  const VoiceVisualizerStyle.bars({
    this.colors = const [],
    this.inactiveColor,
    this.barCount = 24,
    this.spacing = 3,
    this.cornerRadius = 8,
    this.glow = 0.2,
    this.density = 1,
    this.scale = 1,
    this.symmetric = false,
    this.direction = VoiceVisualizerDirection.both,
  })  : kind = VoiceVisualizerKind.bars,
        assert(barCount >= 3 && barCount <= 128),
        assert(spacing >= 0),
        assert(cornerRadius >= 0),
        assert(glow >= 0 && glow <= 1),
        assert(density > 0 && density <= 3),
        assert(scale > 0 && scale <= 4);

  /// Frequency bars rising from a lower baseline.
  /// See the parameter defaults below; use [copyWith] for additional fields.
  const VoiceVisualizerStyle.upwardBars({
    this.colors = const [],
    this.inactiveColor,
    this.barCount = 24,
    this.spacing = 3,
    this.cornerRadius = 8,
    this.glow = 0.2,
    this.density = 1,
    this.scale = 1,
    this.symmetric = false,
    this.direction = VoiceVisualizerDirection.up,
  })  : kind = VoiceVisualizerKind.upwardBars,
        assert(barCount >= 3 && barCount <= 128),
        assert(spacing >= 0),
        assert(cornerRadius >= 0),
        assert(glow >= 0 && glow <= 1),
        assert(density > 0 && density <= 3),
        assert(scale > 0 && scale <= 4);

  /// Compact rounded bars with voice-focused emphasis.
  /// See the parameter defaults below; use [copyWith] for additional fields.
  const VoiceVisualizerStyle.voiceBars({
    this.colors = const [],
    this.inactiveColor,
    this.barCount = 5,
    this.spacing = 5,
    this.cornerRadius = 12,
    this.glow = 0.25,
    this.density = 1,
    this.scale = 1,
    this.symmetric = true,
    this.direction = VoiceVisualizerDirection.both,
  })  : kind = VoiceVisualizerKind.voiceBars,
        assert(barCount >= 3 && barCount <= 128),
        assert(spacing >= 0),
        assert(cornerRadius >= 0),
        assert(glow >= 0 && glow <= 1),
        assert(density > 0 && density <= 3),
        assert(scale > 0 && scale <= 4);

  /// Rounded radial rays with a seamless spatial gradient.
  /// See the parameter defaults below; use [copyWith] for additional fields.
  const VoiceVisualizerStyle.halo({
    this.colors = const [],
    this.inactiveColor,
    this.barCount = 64,
    this.spacing = 2,
    this.cornerRadius = 8,
    this.glow = 0.3,
    this.density = 1,
    this.scale = 1,
    this.symmetric = true,
    this.direction = VoiceVisualizerDirection.radial,
  })  : kind = VoiceVisualizerKind.halo,
        assert(barCount >= 3 && barCount <= 128),
        assert(spacing >= 0),
        assert(cornerRadius >= 0),
        assert(glow >= 0 && glow <= 1),
        assert(density > 0 && density <= 3),
        assert(scale > 0 && scale <= 4);

  /// Upper spectrum bars above a separated, fading reflection.
  /// See the parameter defaults below; use [copyWith] for additional fields.
  const VoiceVisualizerStyle.mirrorSpectrum({
    this.colors = const [],
    this.inactiveColor,
    this.barCount = 32,
    this.spacing = 3,
    this.cornerRadius = 8,
    this.glow = 0.22,
    this.density = 1,
    this.scale = 1,
    this.symmetric = true,
    this.direction = VoiceVisualizerDirection.both,
  })  : kind = VoiceVisualizerKind.mirrorSpectrum,
        assert(barCount >= 3 && barCount <= 128),
        assert(spacing >= 0),
        assert(cornerRadius >= 0),
        assert(glow >= 0 && glow <= 1),
        assert(density > 0 && density <= 3),
        assert(scale > 0 && scale <= 4);

  /// Broad, smooth strands moving in layered waves.
  /// See the parameter defaults below; use [copyWith] for additional fields.
  const VoiceVisualizerStyle.ribbon({
    this.colors = const [],
    this.inactiveColor,
    this.glow = 0.28,
    this.density = 1,
    this.scale = 1,
    this.symmetric = true,
    this.direction = VoiceVisualizerDirection.both,
  })  : kind = VoiceVisualizerKind.ribbon,
        barCount = 32,
        spacing = 3,
        cornerRadius = 8,
        assert(glow >= 0 && glow <= 1),
        assert(density > 0 && density <= 3),
        assert(scale > 0 && scale <= 4);

  /// Fluid orb membranes with a Canvas fallback.
  /// See the parameter defaults below; use [copyWith] for additional fields.
  const VoiceVisualizerStyle.liquidOrb({
    this.colors = const [],
    this.inactiveColor,
    this.glow = 0.45,
    this.density = 1.2,
    this.scale = 1,
    this.symmetric = true,
  })  : kind = VoiceVisualizerKind.liquidOrb,
        barCount = 48,
        spacing = 2,
        cornerRadius = 8,
        direction = VoiceVisualizerDirection.radial,
        assert(glow >= 0 && glow <= 1),
        assert(density > 0 && density <= 3),
        assert(scale > 0 && scale <= 4);

  /// Expanding rings with a central core.
  /// See the parameter defaults below; use [copyWith] for additional fields.
  const VoiceVisualizerStyle.pulseRings({
    this.colors = const [],
    this.inactiveColor,
    this.glow = 0.35,
    this.density = 1,
    this.scale = 1,
    this.symmetric = true,
  })  : kind = VoiceVisualizerKind.pulseRings,
        barCount = 5,
        spacing = 4,
        cornerRadius = 8,
        direction = VoiceVisualizerDirection.radial,
        assert(glow >= 0 && glow <= 1),
        assert(density > 0 && density <= 3),
        assert(scale > 0 && scale <= 4);

  /// Frequency dots with faint trails to a baseline.
  /// See the parameter defaults below; use [copyWith] for additional fields.
  const VoiceVisualizerStyle.dotSpectrum({
    this.colors = const [],
    this.inactiveColor,
    this.barCount = 28,
    this.spacing = 5,
    this.glow = 0.35,
    this.density = 1,
    this.scale = 1,
    this.symmetric = false,
    this.direction = VoiceVisualizerDirection.up,
  })  : kind = VoiceVisualizerKind.dotSpectrum,
        cornerRadius = 8,
        assert(barCount >= 3 && barCount <= 128),
        assert(spacing >= 0),
        assert(glow >= 0 && glow <= 1),
        assert(density > 0 && density <= 3),
        assert(scale > 0 && scale <= 4);

  /// Persistent tracks filled according to frequency energy.
  /// See the parameter defaults below; use [copyWith] for additional fields.
  const VoiceVisualizerStyle.capsuleBars({
    this.colors = const [],
    this.inactiveColor,
    this.barCount = 20,
    this.spacing = 4,
    this.cornerRadius = 99,
    this.glow = 0.18,
    this.density = 1,
    this.scale = 1,
    this.symmetric = false,
    this.direction = VoiceVisualizerDirection.up,
  })  : kind = VoiceVisualizerKind.capsuleBars,
        assert(barCount >= 3 && barCount <= 128),
        assert(spacing >= 0),
        assert(cornerRadius >= 0),
        assert(glow >= 0 && glow <= 1),
        assert(density > 0 && density <= 3),
        assert(scale > 0 && scale <= 4);

  /// Continuous rounded petals surrounding a gradient-filled bloom.
  /// See the parameter defaults below; use [copyWith] for additional fields.
  const VoiceVisualizerStyle.voiceBloom({
    this.colors = const [],
    this.inactiveColor,
    this.barCount = 24,
    this.spacing = 2,
    this.glow = 0.48,
    this.density = 1,
    this.scale = 1,
    this.symmetric = true,
    this.direction = VoiceVisualizerDirection.radial,
  })  : kind = VoiceVisualizerKind.voiceBloom,
        cornerRadius = 12,
        assert(barCount >= 3 && barCount <= 128),
        assert(spacing >= 0),
        assert(glow >= 0 && glow <= 1),
        assert(density > 0 && density <= 3),
        assert(scale > 0 && scale <= 4);

  /// Compact waveform line for small controls.
  /// See the parameter defaults below; use [copyWith] for additional fields.
  const VoiceVisualizerStyle.minimalLine({
    this.colors = const [],
    this.inactiveColor,
    this.glow = 0.12,
    this.density = 1,
    this.scale = 1,
    this.symmetric = false,
    this.direction = VoiceVisualizerDirection.both,
  })  : kind = VoiceVisualizerKind.minimalLine,
        barCount = 32,
        spacing = 3,
        cornerRadius = 8,
        assert(glow >= 0 && glow <= 1),
        assert(density > 0 && density <= 3),
        assert(scale > 0 && scale <= 4);

  /// Copies the style with any supplied field replaced.
  ///
  /// Null parameters preserve existing values. Set [clearInactiveColor] to true
  /// to remove the resting color; this takes precedence over [inactiveColor].
  /// Changing [kind] preserves other values rather than applying that kind’s preset.
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
    double? scale,
    bool? symmetric,
    VoiceVisualizerDirection? direction,
  }) =>
      VoiceVisualizerStyle(
        kind: kind ?? this.kind,
        colors: colors ?? this.colors,
        inactiveColor:
            clearInactiveColor ? null : inactiveColor ?? this.inactiveColor,
        barCount: barCount ?? this.barCount,
        spacing: spacing ?? this.spacing,
        cornerRadius: cornerRadius ?? this.cornerRadius,
        glow: glow ?? this.glow,
        density: density ?? this.density,
        scale: scale ?? this.scale,
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
          scale == other.scale &&
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
        scale,
        symmetric,
        direction,
      );
}
