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
  static const maxColorStops = 4;

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
    if (colors.length > maxColorStops) {
      throw ArgumentError('GPU palettes support at most four colors');
    }
    final primary = colors.first;
    final secondary = colors.last;
    final inactive = style.inactiveColor ?? primary;

    shader
      // uCoreData (0, 1, 2, 3)
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, phase)
      ..setFloat(3, style.scale)
      
      // uAudioData1 (4, 5, 6, 7)
      ..setFloat(4, spectrum.bass)
      ..setFloat(5, spectrum.mids)
      ..setFloat(6, spectrum.treble)
      ..setFloat(7, spectrum.level)
      
      // uAudioData2 (8, 9, 10, 11)
      ..setFloat(8, spectrum.peak)
      ..setFloat(9, spectrum.voiceActivity)
      ..setFloat(10, idleBreathing)
      ..setFloat(11, style.inactiveColor == null ? 0.0 : 1.0)
      
      // uStyleFlags (12, 13, 14, 15)
      ..setFloat(12, style.glow)
      ..setFloat(13, style.density)
      ..setFloat(14, reducedMotion ? 1.0 : 0.0)
      ..setFloat(15, _mode(style.kind))
      
      // uStyleConfig (16, 17, 18, 19)
      ..setFloat(16, style.symmetric ? 1.0 : 0.0)
      ..setFloat(17, _direction(style.direction))
      ..setFloat(18, style.barCount.toDouble())
      ..setFloat(19, colors.length.toDouble())
      
      // uBands03 (20, 21, 22, 23)
      ..setFloat(20, _sampleBand(spectrum.bands, 0.0))
      ..setFloat(21, _sampleBand(spectrum.bands, 1 / 7))
      ..setFloat(22, _sampleBand(spectrum.bands, 2 / 7))
      ..setFloat(23, _sampleBand(spectrum.bands, 3 / 7))
      
      // uBands47 (24, 25, 26, 27)
      ..setFloat(24, _sampleBand(spectrum.bands, 4 / 7))
      ..setFloat(25, _sampleBand(spectrum.bands, 5 / 7))
      ..setFloat(26, _sampleBand(spectrum.bands, 6 / 7))
      ..setFloat(27, _sampleBand(spectrum.bands, 1.0));
      
    // Colors
    _setColor(28, primary);
    _setColor(32, secondary);
    _setColor(36, inactive);
    _setColor(40, colors.length > 1 ? colors[1] : primary);
    _setColor(44, colors.length > 2 ? colors[2] : secondary);
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
