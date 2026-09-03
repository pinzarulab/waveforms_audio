import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../audio/frequency_analyzer.dart';

enum ReactiveVisualizerStyle { orb, wave, bars, upwardBars, voiceBars, halo }

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
  final Color? inactiveColor;
  final bool reducedMotion;

  ReactiveWaveformPainter({
    required this.animation,
    this.style = ReactiveVisualizerStyle.orb,
    this.color = const Color(0xFF72F5D1),
    this.secondaryColor = const Color(0xFF6B8CFF),
    this.inactiveColor,
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
      case ReactiveVisualizerStyle.upwardBars:
        _bars(canvas, size, upward: true);
      case ReactiveVisualizerStyle.voiceBars:
        _voiceBars(canvas, size);
      case ReactiveVisualizerStyle.halo:
        _halo(canvas, size);
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
    final color = _energyColor(_activity, 0);
    final secondaryColor = _energyColor(_activity, 1);
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
    final color = _energyColor(_activity, 0);
    final secondaryColor = _energyColor(_activity, 1);
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

  double get _activity {
    final spectrum = animation.value.spectrum;
    return math.max(
      spectrum.level,
      math.max(spectrum.bass, math.max(spectrum.mids, spectrum.treble)),
    );
  }

  Color _energyColor(double energy, double position) {
    final activeColor = Color.lerp(
      color,
      secondaryColor,
      position.clamp(0.0, 1.0),
    )!;
    if (inactiveColor == null) return activeColor;
    // Fade only when a resting color was explicitly supplied.
    final activity = Curves.easeOut.transform((energy / 0.25).clamp(0.0, 1.0));
    return Color.lerp(inactiveColor, activeColor, activity)!;
  }

  double _band(int index) {
    final bands = animation.value.spectrum.bands;
    if (bands.isEmpty) return 0;
    index = index.clamp(0, bands.length - 1);
    final previous = bands[math.max(0, index - 1)];
    final next = bands[math.min(bands.length - 1, index + 1)];
    return (bands[index] * 0.7 + (previous + next) * 0.15).clamp(0.0, 1.0);
  }

  void _bars(Canvas canvas, Size size, {bool upward = false}) {
    final bands = animation.value.spectrum.bands;
    if (bands.isEmpty) return;
    final width = size.width * 0.86;
    final left = (size.width - width) / 2;
    final step = width / bands.length;
    final stroke = math.min(size.height * 0.12, math.min(step * 0.52, 10.0));
    final paint = Paint();
    final baseline = size.height * 0.82;
    for (var i = 0; i < bands.length; i++) {
      final amplitude = _band(i);
      final height = stroke + amplitude * (size.height * 0.64 - stroke);
      final x = left + (i + 0.5) * step;
      final bottom = upward ? baseline : (size.height + height) / 2;
      paint.color = _energyColor(amplitude, i / math.max(1, bands.length - 1));
      // Fixed bottom edge: upward bars never extend below their baseline.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - stroke / 2, bottom - height, stroke, height),
          Radius.circular(stroke / 2),
        ),
        paint,
      );
    }
  }

  void _voiceBars(Canvas canvas, Size size) {
    const count = 5;
    const silhouette = [0.55, 0.8, 1.0, 0.8, 0.55];
    final spectrum = animation.value.spectrum;
    final stroke = math.min(size.shortestSide * 0.075, 22.0);
    final step = stroke * 1.65;
    final left = size.width / 2 - step * (count - 1) / 2;
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final start = i * spectrum.bands.length ~/ count;
      final end = (i + 1) * spectrum.bands.length ~/ count;
      var peak = 0.0;
      for (var j = start; j < end; j++) {
        peak = math.max(peak, _band(j));
      }
      final energy = (peak * 0.85 + spectrum.level * 0.15).clamp(0.0, 1.0);
      final height = stroke + energy * size.height * 0.52 * silhouette[i];
      paint.color = _energyColor(energy, i / (count - 1));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(left + i * step, size.height / 2),
            width: stroke,
            height: height,
          ),
          Radius.circular(stroke / 2),
        ),
        paint,
      );
    }
  }

  void _halo(Canvas canvas, Size size) {
    const count = 64;
    final spectrum = animation.value.spectrum;
    final unit = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = unit * (0.26 + (reducedMotion ? 0 : spectrum.bass * 0.025));
    final glowRadius = unit * 0.43;
    canvas.drawCircle(
      center,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: _activity * 0.12),
            secondaryColor.withValues(alpha: _activity * 0.04),
            secondaryColor.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: glowRadius)),
    );
    final paint = Paint()
      ..strokeWidth = math.min(3.0, unit * 0.008)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      final angle = i * 2 * math.pi / count - math.pi / 2;
      // Mirror the spectrum around the ring to avoid a bass/treble seam.
      final position = (1 - math.cos(i * 2 * math.pi / count)) / 2;
      final bandPosition = position * math.max(0, spectrum.bands.length - 1);
      final low = bandPosition.floor();
      final energy =
          _band(low) + (_band(low + 1) - _band(low)) * (bandPosition - low);
      final length = unit * (0.008 + energy * 0.095);
      final direction = Offset(math.cos(angle), math.sin(angle));
      paint.color = _energyColor(energy, position);
      canvas.drawLine(
        center + direction * radius,
        center + direction * (radius + length),
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
      oldDelegate.inactiveColor != inactiveColor ||
      oldDelegate.reducedMotion != reducedMotion;
}
