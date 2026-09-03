import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'visualizer_painter.dart';

class CircularWaveformPainter extends VisualizerPainter {
  final double minRadius;
  final double maxRadius;
  final bool animatePulsate;
  final bool animateRotation;

  CircularWaveformPainter({
    required super.audioData,
    required super.color,
    required super.strokeWidth,
    this.minRadius = 50.0,
    this.maxRadius = 150.0,
    this.animatePulsate = false,
    this.animateRotation = false,
    super.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (audioData.samples.isEmpty) return;

    final int sampleCount = audioData.samples.length;
    final Offset center = Offset(size.width / 2, size.height / 2);

    // Fit the full envelope, including round caps, inside the available size.
    final availableRadius = math.max(
      0.0,
      (size.shortestSide - waveformPaint.strokeWidth) / 2,
    );
    final fit = maxRadius > 0
        ? math.min(1.0, availableRadius / maxRadius)
        : 1.0;
    final double radiusRange = (maxRadius - minRadius) * fit;
    final double angleStep = (2 * math.pi) / sampleCount;

    final points = Float32List(sampleCount * 4);

    // Animation effects
    final double scale = animatePulsate ? pulseScale : 1.0;
    final double rotationOffset = animateRotation
        ? (animationValue * 2 * math.pi)
        : 0.0;

    for (int i = 0; i < sampleCount; i++) {
      final double sample = audioData.samples[i] * scale;
      final double angle = (i * angleStep) + rotationOffset - math.pi / 2;

      final double innerRadius = minRadius * fit;
      final double outerRadius = innerRadius + (sample * radiusRange);

      final double cosA = math.cos(angle);
      final double sinA = math.sin(angle);

      // Inner point
      points[i * 4] = center.dx + innerRadius * cosA;
      points[i * 4 + 1] = center.dy + innerRadius * sinA;
      points[i * 4 + 2] = center.dx + outerRadius * cosA;
      points[i * 4 + 3] = center.dy + outerRadius * sinA;
    }

    if (points.isNotEmpty) {
      canvas.drawRawPoints(PointMode.lines, points, waveformPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CircularWaveformPainter oldDelegate) {
    return super.shouldRepaint(oldDelegate) ||
        oldDelegate.minRadius != minRadius ||
        oldDelegate.maxRadius != maxRadius ||
        oldDelegate.animatePulsate != animatePulsate ||
        oldDelegate.animateRotation != animateRotation;
  }
}
