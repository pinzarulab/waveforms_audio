import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../shaders/visualizer_effects_shader.dart';
import '../styles/voice_visualizer_style.dart';
import 'reactive_waveform_painter.dart';

class ShaderWaveformPainter extends CustomPainter {
  final ValueListenable<ReactiveFrame> animation;
  final VisualizerEffectsShaderInstance shader;
  final VoiceVisualizerStyle style;
  final double idleBreathing;
  final bool reducedMotion;

  ShaderWaveformPainter({
    required this.animation,
    required this.shader,
    required this.style,
    required this.idleBreathing,
    required this.reducedMotion,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final frame = animation.value;
    shader.update(
      size: size,
      spectrum: frame.spectrum,
      phase: frame.phase,
      style: style,
      idleBreathing: idleBreathing,
      reducedMotion: reducedMotion,
    );
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader.shader);
  }

  @override
  bool shouldRepaint(covariant ShaderWaveformPainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.shader != shader ||
      oldDelegate.style != style ||
      oldDelegate.idleBreathing != idleBreathing ||
      oldDelegate.reducedMotion != reducedMotion;
}
