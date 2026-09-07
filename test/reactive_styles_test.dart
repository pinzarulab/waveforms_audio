import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waveforms_audio/waveforms_audio.dart';
import 'package:waveforms_audio/src/audio/frequency_analyzer.dart';
import 'package:waveforms_audio/src/painters/reactive_waveform_painter.dart';

class _RecordingCanvas implements Canvas {
  final paths = <Path>[];
  @override
  void drawPath(Path path, Paint paint) => paths.add(Path.from(path));

  final bars = <({RRect shape, Color color})>[];
  final lines = <({Offset start, Offset end, Color color, Shader? shader})>[];
  @override
  void drawRRect(RRect rrect, Paint paint) =>
      bars.add((shape: rrect, color: paint.color));
  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    if (paint.maskFilter == null) {
      lines.add((start: p1, end: p2, color: paint.color, shader: paint.shader));
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  const inactive = Color(0xFF995566);
  const active = Color(0xFF22DD66);
  const secondary = Color(0xFF66FFCC);
  const size = Size(320, 240);

  _RecordingCanvas draw(
    VoiceVisualizerKind kind,
    double energy, {
    Color? idleColor = inactive,
  }) {
    final frame = ValueNotifier(
      ReactiveFrame(
        AudioSpectrum(
          bands: List.filled(32, energy),
          bass: energy,
          mids: energy,
          treble: energy,
          level: energy,
        ),
        1,
      ),
    );
    final canvas = _RecordingCanvas();
    ReactiveWaveformPainter(
      animation: frame,
      style: VoiceVisualizerStyle(
        kind: kind,
        colors: const [active, secondary],
        inactiveColor: idleColor,
        barCount: kind == VoiceVisualizerKind.voiceBars
            ? 5
            : kind == VoiceVisualizerKind.halo
                ? 64
                : 32,
      ),
    ).paint(canvas, size);
    frame.dispose();
    return canvas;
  }

  test(
    'upward bars hold one baseline while rising and returning to idle color',
    () {
      final defaultIdle = draw(
        VoiceVisualizerKind.upwardBars,
        0,
        idleColor: null,
      );
      expect(defaultIdle.bars.first.color.toARGB32(), active.toARGB32());
      expect(defaultIdle.bars.last.color.toARGB32(), secondary.toARGB32());
      final idle = draw(VoiceVisualizerKind.upwardBars, 0);
      final loud = draw(VoiceVisualizerKind.upwardBars, 1);
      expect(idle.bars.length, 32);
      for (var i = 0; i < idle.bars.length; i++) {
        final loudBar = loud.bars[i * 2 + 1];
        expect(idle.bars[i].color.toARGB32(), inactive.toARGB32());
        expect(loudBar.shape.bottom, closeTo(idle.bars[i].shape.bottom, 1e-8));
        expect(loudBar.shape.top, lessThan(idle.bars[i].shape.top));
        expect(loudBar.shape.top, greaterThanOrEqualTo(0));
        expect(loudBar.shape.bottom, lessThanOrEqualTo(size.height));
      }
      expect(loud.bars[1].color.toARGB32(), active.toARGB32());
      expect(loud.bars.last.color.toARGB32(), secondary.toARGB32());
      final quiet = draw(VoiceVisualizerKind.upwardBars, 0.05);
      expect(quiet.bars.first.color.toARGB32(), isNot(inactive.toARGB32()));
      expect(quiet.bars.first.color.toARGB32(), isNot(active.toARGB32()));
    },
  );

  test('voice bars stay centered and collapse into five idle pills', () {
    final idle = draw(VoiceVisualizerKind.voiceBars, 0);
    final loud = draw(VoiceVisualizerKind.voiceBars, 1);
    expect(idle.bars.length, 5);
    for (var i = 0; i < 5; i++) {
      expect(idle.bars[i].color.toARGB32(), inactive.toARGB32());
      expect(
        idle.bars[i].shape.height,
        closeTo(idle.bars[i].shape.width, 1e-10),
      );
      expect(loud.bars[i].shape.center.dy, closeTo(size.height / 2, 1e-10));
      expect(loud.bars[i].shape.height, greaterThan(idle.bars[i].shape.height));
    }
    expect(
      loud.bars[2].shape.height,
      greaterThan(loud.bars.first.shape.height),
    );
  });

  test('minimal line stays rounded with sharp bands and low density', () {
    for (final density in [0.001, 1.0, 3.0]) {
      for (final symmetric in [false, true]) {
        final frame = ValueNotifier(ReactiveFrame(
            AudioSpectrum(
                bands: List.generate(32, (i) => i.isEven ? 1.0 : 0.0),
                level: 0.8),
            0.8));
        final canvas = _RecordingCanvas();
        ReactiveWaveformPainter(
          animation: frame,
          style: VoiceVisualizerStyle.minimalLine(
              density: density, symmetric: symmetric, glow: 0),
        ).paint(canvas, const Size(400, 160));
        final path = canvas.paths.single;
        final metric = path.computeMetrics().single;
        expect(path.getBounds().top.isFinite, isTrue);
        expect(metric.getTangentForOffset(0)!.position.dy, closeTo(80, 0.01));
        expect(metric.getTangentForOffset(metric.length)!.position.dy,
            closeTo(80, 0.01));
        var maxTurn = 0.0;
        var previous = metric.getTangentForOffset(0)!.vector;
        for (var offset = 0.5; offset < metric.length; offset += 0.5) {
          final vector = metric.getTangentForOffset(offset)!.vector;
          final turn = math
              .atan2(previous.dx * vector.dy - previous.dy * vector.dx,
                  previous.dx * vector.dx + previous.dy * vector.dy)
              .abs();
          maxTurn = math.max(maxTurn, turn);
          previous = vector;
        }
        expect(maxTurn, lessThan(0.15),
            reason: 'No angular kinks at density $density');
        expect(path.getBounds().height, greaterThan(10),
            reason: 'Retain audio response');
        frame.dispose();
      }
    }
  });

  test('minimal line stays flat for silence and reduced motion', () {
    for (final reduced in [false, true]) {
      final frame = ValueNotifier(ReactiveFrame(
          AudioSpectrum(
              bands: List.filled(32, reduced ? 1 : 0), level: reduced ? 1 : 0),
          1));
      final canvas = _RecordingCanvas();
      ReactiveWaveformPainter(
        animation: frame,
        style: const VoiceVisualizerStyle.minimalLine(glow: 0),
        reducedMotion: reduced,
      ).paint(canvas, const Size(400, 160));
      expect(canvas.paths.single.getBounds().height, closeTo(0, 1e-8));
      frame.dispose();
    }
  });

  test('mirror separates solid bars from shorter fading reflections', () {
    final mirror = draw(VoiceVisualizerKind.mirrorSpectrum, 0.8);
    expect(mirror.bars.length, 64);
    for (var i = 0; i < 64; i += 2) {
      final upper = mirror.bars[i].shape;
      final reflection = mirror.bars[i + 1].shape;
      expect(upper.bottom, lessThan(reflection.top));
      expect(reflection.height, closeTo(upper.height * 0.72, 1e-8));
      expect(upper.left, reflection.left);
    }
  });

  test('halo has 64 idle segments that extend outwards with audio', () {
    final idle = draw(VoiceVisualizerKind.halo, 0);
    final loud = draw(VoiceVisualizerKind.halo, 1);
    expect(idle.lines.length, 64);
    for (var i = 0; i < 64; i++) {
      expect(idle.lines[i].shader, isNotNull);
      expect(
        (loud.lines[i].end - loud.lines[i].start).distance,
        greaterThan((idle.lines[i].end - idle.lines[i].start).distance),
      );
      expect((Offset.zero & size).contains(loud.lines[i].end), isTrue);
    }
  });

  test(
    'all styles render tiny and wide bounds, silence, and reduced motion',
    () {
      for (final kind in VoiceVisualizerKind.values) {
        for (final bounds in [const Size(12, 12), const Size(420, 80)]) {
          for (final energy in [0.0, 1.0]) {
            final recorder = ui.PictureRecorder();
            final frame = ValueNotifier(
              ReactiveFrame(
                AudioSpectrum(
                  bands: List.filled(3, energy),
                  level: energy,
                  bass: energy,
                  mids: energy,
                  treble: energy,
                ),
                0.5,
              ),
            );
            ReactiveWaveformPainter(
              animation: frame,
              style: VoiceVisualizerStyle(kind: kind),
              reducedMotion: true,
            ).paint(Canvas(recorder), bounds);
            recorder.endRecording().dispose();
            frame.dispose();
          }
        }
      }
    },
  );
}
