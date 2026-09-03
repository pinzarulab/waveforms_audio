import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'visualizer_painter.dart';

class OvalWaveformPainter extends VisualizerPainter {
  final double minWidth;
  final double minHeight;
  final double maxAmplitudeExpansion;
  final bool animatePulsate;
  final bool animateRotation;

  OvalWaveformPainter({
    required super.audioData,
    required super.color,
    required super.strokeWidth,
    this.minWidth = 100.0,
    this.minHeight = 60.0,
    this.maxAmplitudeExpansion = 50.0,
    this.animatePulsate = false,
    this.animateRotation = false,
    super.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (audioData.samples.isEmpty) return;

    final int sampleCount = audioData.samples.length;
    final Offset center = Offset(size.width / 2, size.height / 2);

    final double angleStep = (2 * math.pi) / sampleCount;

    final points = Float32List(sampleCount * 4);

    final double scale = animatePulsate ? pulseScale : 1.0;
    final double rotationOffset = animateRotation
        ? (animationValue * 2 * math.pi)
        : 0.0;

    final outerWidth = minWidth / 2 + maxAmplitudeExpansion;
    final outerHeight = minHeight / 2 + maxAmplitudeExpansion;
    final extentX = animateRotation
        ? math.max(outerWidth, outerHeight)
        : outerWidth;
    final extentY = animateRotation
        ? math.max(outerWidth, outerHeight)
        : outerHeight;
    final fit = math.min(
      1.0,
      math.max(
        0.0,
        math.min(
          (size.width - waveformPaint.strokeWidth) / (2 * extentX),
          (size.height - waveformPaint.strokeWidth) / (2 * extentY),
        ),
      ),
    );
    final cosRotation = math.cos(rotationOffset);
    final sinRotation = math.sin(rotationOffset);

    for (int i = 0; i < sampleCount; i++) {
      final double sample = audioData.samples[i] * scale;
      final double angle = (i * angleStep) - math.pi / 2;

      final double innerX = minWidth / 2;
      final double innerY = minHeight / 2;

      final double outerX = innerX + (sample * maxAmplitudeExpansion);
      final double outerY = innerY + (sample * maxAmplitudeExpansion);

      final double cosA = math.cos(angle);
      final double sinA = math.sin(angle);

      // Rotate the whole ellipse around its center, preserving its shape.
      points[i * 4] =
          center.dx +
          fit * (innerX * cosA * cosRotation - innerY * sinA * sinRotation);
      points[i * 4 + 1] =
          center.dy +
          fit * (innerX * cosA * sinRotation + innerY * sinA * cosRotation);
      points[i * 4 + 2] =
          center.dx +
          fit * (outerX * cosA * cosRotation - outerY * sinA * sinRotation);
      points[i * 4 + 3] =
          center.dy +
          fit * (outerX * cosA * sinRotation + outerY * sinA * cosRotation);
    }

    if (points.isNotEmpty) {
      canvas.drawRawPoints(PointMode.lines, points, waveformPaint);
    }
  }

  @override
  bool shouldRepaint(covariant OvalWaveformPainter oldDelegate) {
    return super.shouldRepaint(oldDelegate) ||
        oldDelegate.minWidth != minWidth ||
        oldDelegate.minHeight != minHeight ||
        oldDelegate.maxAmplitudeExpansion != maxAmplitudeExpansion ||
        oldDelegate.animatePulsate != animatePulsate ||
        oldDelegate.animateRotation != animateRotation;
  }
}
