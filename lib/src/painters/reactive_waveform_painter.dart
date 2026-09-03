import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../audio/frequency_analyzer.dart';

enum ReactiveVisualizerStyle { orb, wave, bars }

class ReactiveFrame {
  final AudioSpectrum spectrum;
  final double phase;
  const ReactiveFrame(this.spectrum, this.phase);
}

/// Paints directly from a listenable so audio frames do not rebuild the UI.
class ReactiveWaveformPainter extends CustomPainter {
  final ValueListenable<ReactiveFrame> animation;
  final ReactiveVisualizerStyle style;
  final Color color;
  final Color secondaryColor;
  final bool reducedMotion;

  ReactiveWaveformPainter({
    required this.animation,
    this.style = ReactiveVisualizerStyle.orb,
    this.color = const Color(0xFF72F5D1),
    this.secondaryColor = const Color(0xFF6B8CFF),
    this.reducedMotion = false,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    switch (style) {
      case ReactiveVisualizerStyle.orb:
        _orb(canvas, size);
      case ReactiveVisualizerStyle.wave:
        _wave(canvas, size);
      case ReactiveVisualizerStyle.bars:
        _bars(canvas, size);
    }
    canvas.restore();
  }

  void _orb(Canvas canvas, Size size) {
    final frame = animation.value;
    final spectrum = frame.spectrum;
    final phase = reducedMotion ? 0.0 : frame.phase;
    final bass = reducedMotion ? 0.0 : spectrum.bass;
    final mids = reducedMotion ? 0.0 : spectrum.mids;
    final treble = reducedMotion ? 0.0 : spectrum.treble;
    final center = Offset(size.width / 2, size.height / 2);
    final unit = size.shortestSide;
    final radius =
        unit *
        (0.23 + bass * 0.045 + (reducedMotion ? 0 : spectrum.level) * 0.025);
    final glowRadius = radius * 1.6;
    canvas.drawCircle(
      center,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.09 + spectrum.level * 0.12),
            secondaryColor.withValues(alpha: 0.04),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: glowRadius)),
    );

    // Three continuous membranes share the beat, but deform independently.
    for (var layer = 2; layer >= 0; layer--) {
      final offset = layer * 1.9;
      final points = <Offset>[];
      for (var i = 0; i < 96; i++) {
        final angle = i * 2 * math.pi / 96;
        final deformation =
            math.sin(angle * 3 + phase * 1.7 + offset) * mids * 0.065 +
            math.sin(angle * 2 - phase * 1.1 + offset) * bass * 0.04 +
            math.sin(angle * 7 + phase * 2.3 + offset) * treble * 0.018;
        final r = radius * (1 + layer * 0.055 + deformation);
        points.add(center + Offset(math.cos(angle), math.sin(angle)) * r);
      }
      final path = _closedCurve(points);
      final bounds = Rect.fromCircle(center: center, radius: radius * 1.25);
      if (layer == 0) {
        canvas.drawPath(
          path,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.45, -0.5),
              radius: 1.1,
              colors: [
                Color.lerp(color, Colors.white, 0.35)!,
                color,
                secondaryColor,
                Color.lerp(secondaryColor, Colors.black, 0.65)!,
              ],
              stops: const [0, 0.28, 0.70, 1],
            ).createShader(bounds),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.75),
                color.withValues(alpha: 0.06),
              ],
            ).createShader(bounds),
        );
      } else {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.fill
            ..color = Color.lerp(
              color,
              secondaryColor,
              layer / 2,
            )!.withValues(alpha: 0.10),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1
            ..color = Color.lerp(
              color,
              secondaryColor,
              layer / 2,
            )!.withValues(alpha: 0.25),
        );
      }
    }
  }

  Path _closedCurve(List<Offset> points) {
    final first = (points.last + points.first) / 2;
    final path = Path()..moveTo(first.dx, first.dy);
    for (var i = 0; i < points.length; i++) {
      final next = (points[i] + points[(i + 1) % points.length]) / 2;
      path.quadraticBezierTo(points[i].dx, points[i].dy, next.dx, next.dy);
    }
    return path..close();
  }

  void _wave(Canvas canvas, Size size) {
    final frame = animation.value;
    final spectrum = frame.spectrum;
    final phase = reducedMotion ? 0.0 : frame.phase;
    final centerY = size.height / 2;
    for (var layer = 3; layer >= 0; layer--) {
      final top = <Offset>[];
      final bottom = <Offset>[];
      for (var i = 0; i <= 120; i++) {
        final x = i / 120;
        final taper = math.pow(math.sin(x * math.pi), 1.5).toDouble();
        final envelope = spectrum.level * 0.10 + spectrum.bass * 0.09;
        final carrier =
            math.sin(x * math.pi * 4 - phase * 2 + layer * 0.7) *
                spectrum.mids *
                0.075 +
            math.sin(x * math.pi * 10 + phase * 1.4 + layer) *
                spectrum.treble *
                0.025;
        final displacement =
            (envelope + carrier) * taper * size.height * (1 - layer * 0.12);
        final thickness = 1.0 + taper * spectrum.level * size.height * 0.035;
        top.add(Offset(x * size.width, centerY - displacement - thickness));
        bottom.add(Offset(x * size.width, centerY + displacement + thickness));
      }
      final path = Path()..moveTo(top.first.dx, top.first.dy);
      for (final point in top.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      for (final point in bottom.reversed) {
        path.lineTo(point.dx, point.dy);
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: [
              color.withValues(alpha: layer == 0 ? 0.7 : 0.13),
              secondaryColor.withValues(alpha: layer == 0 ? 0.8 : 0.18),
            ],
          ).createShader(Offset.zero & size),
      );
    }
  }

  void _bars(Canvas canvas, Size size) {
    final bands = animation.value.spectrum.bands;
    if (bands.isEmpty) return;
    final width = size.width * 0.86;
    final left = (size.width - width) / 2;
    final step = width / bands.length;
    final stroke = (step * 0.52).clamp(1.0, 10.0);
    final paint = Paint()
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(colors: [color, secondaryColor])
          .createShader(Offset.zero & size);
    for (var i = 0; i < bands.length; i++) {
      // Light spatial smoothing keeps adjacent bands coherent without losing pitch.
      final previous = bands[math.max(0, i - 1)];
      final next = bands[math.min(bands.length - 1, i + 1)];
      final amplitude = bands[i] * 0.7 + (previous + next) * 0.15;
      final height = math.max(stroke, amplitude * size.height * 0.64);
      final x = left + (i + 0.5) * step;
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ReactiveWaveformPainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.style != style ||
      oldDelegate.color != color ||
      oldDelegate.secondaryColor != secondaryColor ||
      oldDelegate.reducedMotion != reducedMotion;
}
