import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/audio_data.dart';

abstract class VisualizerPainter extends CustomPainter {
  final AudioData audioData;
  final Paint waveformPaint;
  final double animationValue;

  VisualizerPainter({
    required this.audioData,
    required Color color,
    required double strokeWidth,
    PaintingStyle style = PaintingStyle.stroke,
    StrokeCap strokeCap = StrokeCap.round,
    this.animationValue = 1.0,
  }) : waveformPaint = Paint()
         ..color = color
         ..strokeWidth = strokeWidth
         ..style = style
         ..strokeCap = strokeCap;

  /// Smooth, periodic breathing. Keeps the waveform visible at its trough,
  /// with matching position and velocity at the loop boundary.
  double get pulseScale => 0.85 + 0.15 * math.cos(animationValue * 2 * math.pi);

  @override
  bool shouldRepaint(covariant VisualizerPainter oldDelegate) {
    return oldDelegate.audioData != audioData ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.waveformPaint.color != waveformPaint.color ||
        oldDelegate.waveformPaint.strokeWidth != waveformPaint.strokeWidth;
  }
}
