import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../audio/frequency_analyzer.dart';
import '../styles/voice_visualizer_style.dart';

class ReactiveFrame {
  final AudioSpectrum spectrum;
  final double phase;
  const ReactiveFrame(this.spectrum, this.phase);
}

class ReactiveWaveformPainter extends CustomPainter {
  final ValueListenable<ReactiveFrame> animation;
  final VoiceVisualizerStyle style;
  final bool reducedMotion;
  final double idleBreathing;

  ReactiveWaveformPainter({
    required this.animation,
    required this.style,
    this.reducedMotion = false,
    this.idleBreathing = 0,
  }) : super(repaint: animation);

  AudioSpectrum get spectrum => animation.value.spectrum;
  double get phase => reducedMotion ? 0 : animation.value.phase;
  List<Color> get palette => style.colors.isEmpty
      ? const [Color(0xFF72F5D1), Color(0xFF6B8CFF)]
      : style.colors;
  double get activity => math.max(
        spectrum.level,
        math.max(
          spectrum.peak,
          math.max(spectrum.bass, math.max(spectrum.mids, spectrum.treble)),
        ),
      );
  double get breath => reducedMotion || idleBreathing == 0
      ? 0
      : idleBreathing * (0.72 + math.sin(phase * math.pi * 2) * 0.28);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(style.scale);
    canvas.translate(-size.width / 2, -size.height / 2);
    _ambientGlow(canvas, size);
    switch (style.kind) {
      case VoiceVisualizerKind.orb:
        _orb(canvas, size);
      case VoiceVisualizerKind.wave:
        _wave(canvas, size);
      case VoiceVisualizerKind.bars:
      case VoiceVisualizerKind.upwardBars:
        _bars(canvas, size);
      case VoiceVisualizerKind.voiceBars:
        _voiceBars(canvas, size);
      case VoiceVisualizerKind.halo:
        _halo(canvas, size);
      case VoiceVisualizerKind.mirrorSpectrum:
        _mirrorSpectrum(canvas, size);
      case VoiceVisualizerKind.ribbon:
        _ribbon(canvas, size);
      case VoiceVisualizerKind.liquidOrb:
        _orb(canvas, size, liquid: true);
      case VoiceVisualizerKind.pulseRings:
        _pulseRings(canvas, size);
      case VoiceVisualizerKind.dotSpectrum:
        _dotSpectrum(canvas, size);
      case VoiceVisualizerKind.capsuleBars:
        _capsuleBars(canvas, size);
      case VoiceVisualizerKind.voiceBloom:
        _voiceBloom(canvas, size);
      case VoiceVisualizerKind.minimalLine:
        _minimalLine(canvas, size);
    }
    canvas.restore();
  }

  Color _activeColor(double position) {
    if (palette.length == 1) return palette.first;
    final scaled = position.clamp(0.0, 1.0) * (palette.length - 1);
    final index = scaled.floor().clamp(0, palette.length - 2);
    return Color.lerp(palette[index], palette[index + 1], scaled - index)!;
  }

  Color _color(double energy, double position) {
    final active = _activeColor(position);
    if (style.inactiveColor case final inactive?) {
      final amount =
          Curves.easeOut.transform((activity / 0.24).clamp(0.0, 1.0));
      return Color.lerp(inactive, active, amount)!;
    }
    return active;
  }

  double _band(double position) {
    final bands = spectrum.bands;
    if (bands.isEmpty) return breath;
    final value = position.clamp(0.0, 1.0) * (bands.length - 1);
    final low = value.floor();
    final high = math.min(low + 1, bands.length - 1);
    final raw = bands[low] + (bands[high] - bands[low]) * (value - low);
    final nearby = bands[math.max(0, low - 1)] +
        bands[math.min(bands.length - 1, high + 1)];
    final idle =
        breath * (0.78 + 0.22 * math.sin(position * math.pi * 5 + phase));
    return math.max(raw * 0.72 + nearby * 0.14, idle).clamp(0.0, 1.0);
  }

  Paint _glow(double position, double energy, double blur) => Paint()
    ..color = _color(
      activity,
      position,
    ).withValues(alpha: style.glow * (0.1 + energy * 0.28))
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

  int _count({int minimum = 3, int maximum = 256}) =>
      (style.barCount * style.density).round().clamp(minimum, maximum);

  double _sourcePosition(double position) =>
      style.symmetric ? (position - 0.5).abs() * 2 : position;

  void _ambientGlow(Canvas canvas, Size size) {
    if (style.glow == 0) return;
    final energy = math.max(activity, breath);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.42;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _color(
              energy,
              0.5,
            ).withValues(alpha: style.glow * (0.025 + energy * 0.07)),
            _color(energy, 0.5).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  void _orb(Canvas canvas, Size size, {bool liquid = false}) {
    final center = Offset(size.width / 2, size.height / 2);
    final unit = size.shortestSide;
    final energy = math.max(activity, breath);
    final radius =
        unit * (liquid ? 0.21 : 0.23) * (1 + spectrum.bass * 0.14 + breath);
    if (style.glow > 0) {
      canvas.drawCircle(center, radius * 1.2, _glow(0.5, energy, unit * 0.09));
    }
    final layers = liquid ? 4 : 3;
    final count = (128 * style.density).round().clamp(96, 384);
    for (var layer = layers - 1; layer >= 0; layer--) {
      final points = <Offset>[];
      for (var i = 0; i < count; i++) {
        final angle = i * math.pi * 2 / count;
        final local = _fluidBand((1 - math.cos(angle)) / 2);
        final deformation = reducedMotion
            ? 0.0
            : math.sin(angle * 3 + phase * 0.8 + layer) *
                    spectrum.mids *
                    0.045 +
                math.sin(angle * (3 + style.density).round().clamp(3, 6) -
                        phase * 1.05) *
                    local *
                    (liquid ? 0.03 : 0.018) +
                math.sin(angle * 2 - phase * 0.6) * spectrum.bass * 0.028;
        final r = radius * (1 + layer * (liquid ? 0.045 : 0.055) + deformation);
        points.add(center + Offset(math.cos(angle), math.sin(angle)) * r);
      }
      final path = _closedCurve(points);
      if (layer == 0) {
        canvas.drawPath(
          path,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.45, -0.5),
              colors: [
                Color.lerp(_color(activity, 0), Colors.white, 0.32)!,
                _color(activity, 0.4),
                _color(activity, 1),
              ],
            ).createShader(
              Rect.fromCircle(center: center, radius: radius * 1.35),
            ),
        );
      } else {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = liquid ? 1.4 : 1
            ..color = _color(
              activity,
              layer / (layers - 1),
            ).withValues(alpha: liquid ? 0.28 : 0.18),
        );
      }
    }
  }

  // Broad, continuously weighted bands avoid corners at FFT bins and the
  // mirrored center. Only fluid styles use this spatial smoothing.
  double _fluidBand(double position) {
    var total = 0.0;
    var weight = 0.0;
    for (var i = 0; i < 8; i++) {
      final distance = (position - i / 7) / 0.22;
      final w = math.exp(-distance * distance * 2);
      total += _band(i / 7) * w;
      weight += w;
    }
    return total / weight;
  }

  double _fluidSource(double position) =>
      style.symmetric ? (1 + math.cos(position * math.pi * 2)) / 2 : position;

  Path _openCurve(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length - 1; i++) {
      final next = (points[i] + points[i + 1]) / 2;
      path.quadraticBezierTo(points[i].dx, points[i].dy, next.dx, next.dy);
    }
    return path..lineTo(points.last.dx, points.last.dy);
  }

  Shader _spatialGradient(Rect bounds, double energy) => LinearGradient(
        colors: List.generate(
          math.max(2, palette.length),
          (i) => _color(energy, i / (math.max(2, palette.length) - 1)),
        ),
      ).createShader(bounds);

  void _wave(Canvas canvas, Size size) {
    final center = size.height / 2;
    final layers = style.symmetric ? 4 : 3;
    for (var layer = layers - 1; layer >= 0; layer--) {
      final points = <Offset>[];
      for (var i = 0; i <= 120; i++) {
        final position = i / 120;
        final taper = math.pow(math.sin(position * math.pi), 1.5).toDouble();
        final energy = _fluidBand(_fluidSource(position));
        final carrier = reducedMotion
            ? 0.0
            : math.sin(
                  position * math.pi * (2.0 + layer * 0.35) - phase * 2 + layer,
                ) *
                energy;
        var y = center - (energy * 0.24 + carrier * 0.12) * taper * size.height;
        if (style.direction == VoiceVisualizerDirection.down) {
          y = size.height - y;
        }
        points.add(Offset(position * size.width, y));
      }
      final path = _openCurve(points);
      final color = _color(activity, layer / math.max(1, layers - 1));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 + (layers - layer) * 0.7
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color.withValues(alpha: layer == 0 ? 0.9 : 0.24),
      );
      if (style.symmetric || style.direction == VoiceVisualizerDirection.both) {
        canvas.save();
        canvas.translate(0, size.height);
        canvas.scale(1, -1);
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = color.withValues(alpha: 0.22),
        );
        canvas.restore();
      }
    }
  }

  ({double width, double gap, double left}) _barLayout(Size size, int count) {
    final content = size.width * 0.88;
    final gap = math.min(style.spacing, content / count * 0.8);
    final width = math.max(1.0, (content - gap * (count - 1)) / count);
    return (width: width, gap: gap, left: (size.width - content) / 2);
  }

  void _bars(Canvas canvas, Size size) {
    final count = _count();
    final layout = _barLayout(size, count);
    final upward = style.kind == VoiceVisualizerKind.upwardBars ||
        style.direction == VoiceVisualizerDirection.up;
    final downward = style.direction == VoiceVisualizerDirection.down;
    final baseline = upward
        ? size.height * 0.84
        : downward
            ? size.height * 0.16
            : size.height / 2;
    for (var i = 0; i < count; i++) {
      final position = i / math.max(1, count - 1);
      final energy = _band(_sourcePosition(position));
      final height = layout.width +
          energy * (size.height * (upward ? 0.66 : 0.58) - layout.width);
      final x = layout.left + i * (layout.width + layout.gap);
      final rect = upward
          ? Rect.fromLTWH(x, baseline - height, layout.width, height)
          : downward
              ? Rect.fromLTWH(x, baseline, layout.width, height)
              : Rect.fromCenter(
                  center: Offset(x + layout.width / 2, baseline),
                  width: layout.width,
                  height: height,
                );
      final radius = Radius.circular(
        math.min(style.cornerRadius, layout.width / 2),
      );
      if (style.glow > 0 && energy > 0.08) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, radius),
          _glow(position, energy, 6),
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()..color = _color(energy, position),
      );
    }
  }

  void _voiceBars(Canvas canvas, Size size) {
    final count = _count();
    final layout = _barLayout(size, count);
    for (var i = 0; i < count; i++) {
      final position = i / math.max(1, count - 1);
      final silhouette = 0.55 + 0.45 * math.sin(position * math.pi);
      final energy = (_band(_sourcePosition(position)) * 0.82 +
              spectrum.voiceActivity * 0.18)
          .clamp(0.0, 1.0);
      final height = layout.width + energy * size.height * 0.52 * silhouette;
      final rect = Rect.fromCenter(
        center: Offset(
          layout.left + layout.width / 2 + i * (layout.width + layout.gap),
          size.height / 2,
        ),
        width: layout.width,
        height: height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          Radius.circular(math.min(style.cornerRadius, layout.width / 2)),
        ),
        Paint()..color = _color(energy, position),
      );
    }
  }

  void _halo(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final unit = size.shortestSide;
    final radius = unit * (0.25 + spectrum.bass * 0.02);
    final bounds = Rect.fromCircle(center: center, radius: unit * 0.38);
    final gradient = _spatialGradient(bounds, activity);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.004
      ..shader = gradient
      ..color = const Color(0x55FFFFFF);
    canvas.drawCircle(center, radius - unit * 0.018, ring);
    final count = _count(minimum: 12, maximum: 192);
    final width = math.min(unit * 0.014, radius * math.pi * 2 / count * 0.55);
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width
      ..shader = gradient;
    for (var i = 0; i < count; i++) {
      final angle = i / count * math.pi * 2 - math.pi / 2;
      final energy = _fluidBand((1 - math.cos(angle)) / 2);
      final direction = Offset(math.cos(angle), math.sin(angle));
      final start = center + direction * radius;
      final end =
          center + direction * (radius + unit * (0.012 + energy * 0.09));
      if (style.glow > 0) {
        canvas.drawLine(
          start,
          end,
          Paint()
            ..strokeCap = StrokeCap.round
            ..strokeWidth = width * 1.5
            ..shader = gradient
            ..color = Color.fromRGBO(255, 255, 255, style.glow * 0.35)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * 0.012),
        );
      }
      canvas.drawLine(start, end, paint);
    }
  }

  void _mirrorSpectrum(Canvas canvas, Size size) {
    final count = _count();
    final layout = _barLayout(size, count);
    final baseline = size.height * 0.48;
    final gap = math.min(size.height * 0.035, math.max(2.0, style.spacing));
    for (var i = 0; i < count; i++) {
      final position = i / math.max(1, count - 1);
      final energy = _band(_sourcePosition(position));
      final height = math.min(
        size.height * 0.40,
        layout.width + energy * size.height * 0.34,
      );
      final x = layout.left + i * (layout.width + layout.gap);
      final radius = Radius.circular(
        math.min(style.cornerRadius, layout.width / 2),
      );
      final color = _color(energy, position);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, baseline - gap / 2 - height, layout.width, height),
          radius,
        ),
        Paint()..color = color,
      );
      final reflection = Rect.fromLTWH(
        x,
        baseline + gap / 2,
        layout.width,
        height * 0.72,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(reflection, radius),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: color.a * 0.48),
              color.withValues(alpha: 0.02),
            ],
          ).createShader(reflection),
      );
    }
  }

  void _ribbon(Canvas canvas, Size size) {
    for (var layer = 4; layer >= 0; layer--) {
      final points = <Offset>[];
      final count = (80 * style.density).round().clamp(32, 240);
      for (var i = 0; i <= count; i++) {
        final position = i / count;
        final energy = _fluidBand(_fluidSource(position));
        final wave = reducedMotion
            ? 0.0
            : math.sin(
                position * math.pi * (1.6 + layer * 0.2) -
                    phase * (1.2 + layer * 0.08),
              );
        final y = size.height / 2 +
            wave * (8 + energy * size.height * 0.22) +
            (layer - 2) * 3;
        points.add(Offset(position * size.width, y));
      }
      final path = _openCurve(points);
      final strokeWidth = 1.2 + (4 - layer) * 0.8;
      final color = _color(activity, layer / 4);
      if (style.glow > 0) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth + 1.5
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = color.withValues(
              alpha: style.glow * (0.06 + (4 - layer) * 0.025),
            )
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              3 + style.glow * 7,
            ),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color.withValues(alpha: 0.22 + (4 - layer) * 0.14),
      );
    }
  }

  void _pulseRings(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.shortestSide * 0.43;
    final energy = math.max(activity, breath);
    final count = _count(maximum: 9);
    for (var i = count - 1; i >= 0; i--) {
      final progress =
          reducedMotion ? i / count : (phase * 0.22 + i / count) % 1;
      canvas.drawCircle(
        center,
        maxRadius * (0.22 + progress * 0.78),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 + energy * 3
          ..color = _color(energy, progress).withValues(
            alpha: ((1 - progress) * (0.18 + energy * 0.65)).clamp(0.0, 1.0),
          ),
      );
    }
    canvas.drawCircle(
      center,
      maxRadius * (0.16 + spectrum.bass * 0.04),
      Paint()..color = _color(energy, 0.35),
    );
  }

  void _dotSpectrum(Canvas canvas, Size size) {
    final count = _count();
    final width = size.width * 0.88;
    final step = width / math.max(1, count - 1);
    final left = (size.width - width) / 2;
    final centered = style.direction == VoiceVisualizerDirection.both;
    final downward = style.direction == VoiceVisualizerDirection.down;
    final baseline = size.height *
        (centered
            ? 0.5
            : downward
                ? 0.18
                : 0.82);
    for (var i = 0; i < count; i++) {
      final position = i / math.max(1, count - 1);
      final energy = _band(_sourcePosition(position));
      final displacement = energy * size.height * (centered ? 0.28 : 0.64);
      final color = _color(energy, position);
      final radius = math.min(2 + energy * 2.2, size.shortestSide * 0.04);
      void dot(double y) {
        final point = Offset(left + i * step, y);
        canvas.drawLine(
          Offset(point.dx, baseline),
          point,
          Paint()
            ..strokeWidth = 1
            ..color = color.withValues(alpha: 0.1 + energy * 0.22),
        );
        if (style.glow > 0) {
          canvas.drawCircle(point, radius + 1, _glow(position, energy, 5));
        }
        canvas.drawCircle(point, radius, Paint()..color = color);
      }

      dot(baseline + (downward ? displacement : -displacement));
      // Both means a centered pair, rather than an upward-only curve that
      // can escape the top of the widget. Merge the pair at rest.
      if (centered && displacement > 0.01) dot(baseline + displacement);
    }
  }

  void _capsuleBars(Canvas canvas, Size size) {
    final count = _count();
    final layout = _barLayout(size, count);
    final trackHeight = size.height * 0.68;
    final top = (size.height - trackHeight) / 2;
    for (var i = 0; i < count; i++) {
      final position = i / math.max(1, count - 1);
      final energy = _band(_sourcePosition(position));
      final x = layout.left + i * (layout.width + layout.gap);
      final radius = Radius.circular(
        math.min(style.cornerRadius, layout.width / 2),
      );
      final active = _color(energy, position);
      final track = style.inactiveColor ?? active;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top, layout.width, trackHeight),
          radius,
        ),
        Paint()
          ..color = track.withValues(
            alpha: style.inactiveColor == null ? 0.18 : 0.42,
          ),
      );
      final fillHeight = math.max(layout.width, trackHeight * energy);
      final fillTop = switch (style.direction) {
        VoiceVisualizerDirection.down => top,
        VoiceVisualizerDirection.both => top + (trackHeight - fillHeight) / 2,
        _ => top + trackHeight - fillHeight,
      };
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, fillTop, layout.width, fillHeight),
          radius,
        ),
        Paint()..color = active,
      );
    }
  }

  void _voiceBloom(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final unit = size.shortestSide;
    final count = _count(minimum: 6, maximum: 12);
    final points = <Offset>[];
    for (var i = 0; i < count * 24; i++) {
      final angle = i / (count * 24) * math.pi * 2 - math.pi / 2;
      final energy = (_fluidBand((1 - math.cos(angle)) / 2) * 0.75 +
              spectrum.voiceActivity * 0.25)
          .clamp(0.0, 1.0);
      final lobe = (1 + math.cos((angle + math.pi / 2) * count)) / 2;
      final radius =
          unit * (0.19 + energy * 0.035 + lobe * (0.014 + energy * 0.035));
      points.add(center + Offset(math.cos(angle), math.sin(angle)) * radius);
    }
    final path = _closedCurve(points);
    final bounds = Rect.fromCircle(center: center, radius: unit * 0.30);
    final gradient = _spatialGradient(bounds, activity);
    if (style.glow > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..shader = gradient
          ..color = Color.fromRGBO(255, 255, 255, style.glow * 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * 0.035),
      );
    }
    canvas.drawPath(path, Paint()..shader = gradient);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.003
        ..color = const Color(0x55FFFFFF),
    );
    canvas.save();
    canvas.clipPath(path);
    canvas.drawCircle(
      center,
      unit * 0.24,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: const [Color(0x38FFFFFF), Color(0x00FFFFFF)],
        ).createShader(bounds),
    );
    canvas.restore();
  }

  void _minimalLine(Canvas canvas, Size size) {
    final points = <Offset>[];
    final count = (100 * style.density).round().clamp(48, 300);
    for (var i = 0; i <= count; i++) {
      final position = i / count;
      final taper = math.sin(position * math.pi);
      final carrier =
          reducedMotion ? 0.0 : math.sin(position * math.pi * 5 - phase * 2.2);
      var y = size.height / 2 -
          carrier *
              _fluidBand(_fluidSource(position)) *
              size.height *
              0.3 *
              taper;
      if (style.direction == VoiceVisualizerDirection.down) y = size.height - y;
      points.add(Offset(position * size.width, y));
    }
    final path = _openCurve(points);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(
        colors: List<Color>.generate(
          math.max(2, palette.length),
          (index) => _color(
            activity,
            index / math.max(1, math.max(2, palette.length) - 1),
          ),
        ),
      ).createShader(Offset.zero & size);
    if (style.glow > 0) {
      canvas.drawPath(
        path,
        Paint.from(paint)
          ..shader = null
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, style.glow * 7)
          ..color = _color(activity, 0.5).withValues(alpha: 0.35),
      );
    }
    canvas.drawPath(path, paint);
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

  @override
  bool shouldRepaint(covariant ReactiveWaveformPainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.style != style ||
      oldDelegate.reducedMotion != reducedMotion ||
      oldDelegate.idleBreathing != idleBreathing;
}
