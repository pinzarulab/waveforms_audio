import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../audio/frequency_analyzer.dart';
import '../styles/voice_visualizer_style.dart';

/// Shared GPU program for visualizers whose glow or fluid geometry benefits
/// from per-pixel rendering.
class VisualizerEffectsShaderProgram {
  static const packageAsset =
      'packages/waveforms_audio/shaders/visualizer_effects.frag';
  static const localAsset = 'shaders/visualizer_effects.frag';
  static Future<ui.FragmentProgram>? _program;

  static Future<ui.FragmentProgram> load() => _program ??= _load();

  static Future<ui.FragmentProgram> _load() async {
    try {
      return await ui.FragmentProgram.fromAsset(packageAsset);
    } catch (_) {
      // Package tests and this package's example expose the root asset key.
      return ui.FragmentProgram.fromAsset(localAsset);
    }
  }
}

class VisualizerEffectsShaderInstance {
  final ui.FragmentShader shader;

  VisualizerEffectsShaderInstance(ui.FragmentProgram program)
    : shader = program.fragmentShader();

  void update({
    required Size size,
    required AudioSpectrum spectrum,
    required double phase,
    required VoiceVisualizerStyle style,
    required double idleBreathing,
    required bool reducedMotion,
  }) {
    final colors = style.colors.isEmpty
        ? const [Color(0xFF72F5D1), Color(0xFF6B8CFF)]
        : style.colors;
    final primary = colors.first;
    final secondary = colors.last;
    final inactive = style.inactiveColor ?? primary;

    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, phase)
      ..setFloat(3, spectrum.bass)
      ..setFloat(4, spectrum.mids)
      ..setFloat(5, spectrum.treble)
      ..setFloat(6, spectrum.level)
      ..setFloat(7, spectrum.peak)
      ..setFloat(8, spectrum.voiceActivity)
      ..setFloat(9, idleBreathing);
    _setColor(10, primary);
    _setColor(14, secondary);
    _setColor(18, inactive);
    shader
      ..setFloat(22, style.inactiveColor == null ? 0 : 1)
      ..setFloat(23, style.glow)
      ..setFloat(24, style.density)
      ..setFloat(25, reducedMotion ? 1 : 0)
      ..setFloat(26, _mode(style.kind))
      ..setFloat(27, style.symmetric ? 1 : 0)
      ..setFloat(28, _direction(style.direction));
    for (var index = 0; index < 8; index++) {
      shader.setFloat(29 + index, _sampleBand(spectrum.bands, index / 7));
    }
  }

  double _sampleBand(List<double> bands, double position) {
    if (bands.isEmpty) return 0;
    final scaled = position * (bands.length - 1);
    final lower = scaled.floor();
    final upper = scaled.ceil();
    return ui.lerpDouble(bands[lower], bands[upper], scaled - lower) ?? 0;
  }

  double _mode(VoiceVisualizerKind kind) => switch (kind) {
    VoiceVisualizerKind.orb => 0,
    VoiceVisualizerKind.wave => 1,
    VoiceVisualizerKind.halo => 2,
    VoiceVisualizerKind.ribbon => 3,
    VoiceVisualizerKind.liquidOrb => 4,
    VoiceVisualizerKind.pulseRings => 5,
    VoiceVisualizerKind.voiceBloom => 6,
    _ => -1,
  };

  double _direction(VoiceVisualizerDirection direction) => switch (direction) {
    VoiceVisualizerDirection.up => 0,
    VoiceVisualizerDirection.down => 1,
    VoiceVisualizerDirection.both => 2,
    VoiceVisualizerDirection.radial => 3,
  };

  void _setColor(int index, Color color) {
    shader
      ..setFloat(index, color.r)
      ..setFloat(index + 1, color.g)
      ..setFloat(index + 2, color.b)
      ..setFloat(index + 3, color.a);
  }

  void dispose() => shader.dispose();
}
