import 'dart:typed_data';
import 'dart:ui';

import 'visualizer_painter.dart';

enum LinearWaveformAlignment { top, center, bottom }

class LinearWaveformPainter extends VisualizerPainter {
  final LinearWaveformAlignment alignment;
  final double spacing;
  final bool animatePulsate;

  LinearWaveformPainter({
    required super.audioData,
    required super.color,
    required super.strokeWidth,
    this.alignment = LinearWaveformAlignment.center,
    this.spacing = 2.0,
    this.animatePulsate = false,
    super.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (audioData.samples.isEmpty) return;

    final double width = size.width;
    final double height = size.height;
    final int sampleCount = audioData.samples.length;

    // Calculate how many samples we can fit if we use fixed width,
    // or calculate dynamic width per sample if we want to fit all.
    // For visualizer, typically we draw all given samples across the width.
    final double stepX = width / sampleCount;

    final points = Float32List(sampleCount * 4);

    // Optional pulsating animation effect
    final double scale = animatePulsate ? pulseScale : 1.0;

    for (int i = 0; i < sampleCount; i++) {
      final double sample = audioData.samples[i] * scale;
      final double x = i * stepX + stepX / 2;
      final double barHeight = sample * height;

      double y1 = 0.0;
      double y2 = 0.0;

      switch (alignment) {
        case LinearWaveformAlignment.top:
          y1 = 0;
          y2 = barHeight;
          break;
        case LinearWaveformAlignment.bottom:
          y1 = height;
          y2 = height - barHeight;
          break;
        case LinearWaveformAlignment.center:
          y1 = height / 2 - barHeight / 2;
          y2 = height / 2 + barHeight / 2;
          break;
      }

      // Add segment for drawRawPoints (lines)
      points[i * 4] = x;
      points[i * 4 + 1] = y1;
      points[i * 4 + 2] = x;
      points[i * 4 + 3] = y2;
    }

    // drawRawPoints is highly optimized for drawing many lines
    if (points.isNotEmpty) {
      canvas.drawRawPoints(PointMode.lines, points, waveformPaint);
    }
  }

  @override
  bool shouldRepaint(covariant LinearWaveformPainter oldDelegate) {
    return super.shouldRepaint(oldDelegate) ||
        oldDelegate.alignment != alignment ||
        oldDelegate.spacing != spacing ||
        oldDelegate.animatePulsate != animatePulsate;
  }
}
