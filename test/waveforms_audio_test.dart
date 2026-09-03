import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waveforms_audio/waveforms_audio.dart';

Widget host(Widget child, {bool reducedMotion = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reducedMotion),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  ),
);

VisualizerPainter painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byType(CustomPaint)).painter!
        as VisualizerPainter;

class RecordingCanvas implements Canvas {
  late Float32List points;

  @override
  void drawRawPoints(ui.PointMode pointMode, Float32List points, Paint paint) {
    this.points = points;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const data = AudioData(samples: [0.2, 0.8, 0.5]);

  test('pulse has a seamless loop and never collapses the waveform', () {
    double scale(double phase) => LinearWaveformPainter(
      audioData: data,
      color: Colors.blue,
      strokeWidth: 2,
      animationValue: phase,
    ).pulseScale;
    expect(scale(0), scale(1));
    expect(scale(0.5), closeTo(0.7, 0.00001));
    expect(scale(0.001), closeTo(scale(0.999), 0.00001));
    expect(scale(0), 1);
  });

  testWidgets(
    'data rebuilds preserve loop progress and duration changes apply',
    (tester) async {
      Widget visualizer(Duration duration, AudioData audio) => host(
        AudioVisualizer(
          audioData: audio,
          type: VisualizerType.circular,
          animatePulsate: true,
          animateRotation: true,
          animationDuration: duration,
        ),
      );
      await tester.pumpWidget(visualizer(const Duration(seconds: 2), data));
      await tester.pump(const Duration(milliseconds: 500));
      expect(painter(tester).animationValue, closeTo(0.25, 0.001));
      await tester.pumpWidget(
        visualizer(
          const Duration(seconds: 2),
          const AudioData(samples: [0.5, 0.2, 0.9]),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(painter(tester).animationValue, closeTo(0.5, 0.001));
      await tester.pumpWidget(visualizer(const Duration(seconds: 4), data));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(painter(tester).animationValue, closeTo(0.625, 0.001));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('amplitude updates retarget from the displayed value', (
    tester,
  ) async {
    Widget visualizer(double amplitude) => host(
      AudioVisualizer(
        audioData: AudioData(samples: [amplitude]),
        transitionDuration: const Duration(milliseconds: 100),
      ),
    );
    await tester.pumpWidget(visualizer(0));
    await tester.pumpWidget(visualizer(1));
    expect(painter(tester).audioData.samples.single, 0);
    await tester.pump(const Duration(milliseconds: 50));
    final midway = painter(tester).audioData.samples.single;
    expect(midway, greaterThan(0));
    expect(midway, lessThan(1));
    await tester.pumpWidget(visualizer(0.2));
    expect(painter(tester).audioData.samples.single, closeTo(midway, 0.0001));
    await tester.pump(const Duration(milliseconds: 100));
    expect(painter(tester).audioData.samples.single, closeTo(0.2, 0.000001));
  });

  testWidgets(
    'reduced motion stops loops and immediately displays fresh data',
    (tester) async {
      Widget visualizer(bool reducedMotion, AudioData audio) => host(
        AudioVisualizer(
          audioData: audio,
          type: VisualizerType.circular,
          animatePulsate: true,
          animateRotation: true,
        ),
        reducedMotion: reducedMotion,
      );
      await tester.pumpWidget(visualizer(false, data));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(
        visualizer(true, const AudioData(samples: [1, 1, 1])),
      );
      final stopped = painter(tester).animationValue;
      expect(
        (painter(tester) as CircularWaveformPainter).animatePulsate,
        isFalse,
      );
      expect(
        (painter(tester) as CircularWaveformPainter).animateRotation,
        isFalse,
      );
      expect(painter(tester).audioData.samples, [1, 1, 1]);
      await tester.pump(const Duration(seconds: 1));
      expect(painter(tester).animationValue, stopped);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(visualizer(false, data));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(painter(tester).animationValue, isNot(stopped));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'zero transition duration and changed sample counts update immediately',
    (tester) async {
      await tester.pumpWidget(host(const AudioVisualizer(audioData: data)));
      await tester.pumpWidget(
        host(
          const AudioVisualizer(
            audioData: AudioData(samples: [1, 1, 1]),
            transitionDuration: Duration.zero,
          ),
        ),
      );
      expect(painter(tester).audioData.samples, [1, 1, 1]);
      await tester.pumpWidget(
        host(AudioVisualizer(audioData: AudioData.empty())),
      );
      expect(painter(tester).audioData.samples, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'live waveform eases samples and survives stream and window changes',
    (tester) async {
      final first = StreamController<List<double>>();
      final second = StreamController<List<double>>();
      Widget live(Stream<List<double>> stream, int size) =>
          host(LiveAudioVisualizer(audioStream: stream, windowSize: size));
      await tester.pumpWidget(live(first.stream, 3));
      first.add([0.8]);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(painter(tester).audioData.samples.last, inExclusiveRange(0, 0.8));
      await tester.pump(const Duration(milliseconds: 50));
      expect(painter(tester).audioData.samples, [0, 0, 0.8]);
      await tester.pumpWidget(live(second.stream, 2));
      expect(first.hasListener, isFalse);
      expect(painter(tester).audioData.samples, [0, 0.8]);
      second.add([0.4]);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(painter(tester).audioData.samples, [0.8, 0.4]);
      await tester.pumpWidget(live(second.stream, 4));
      expect(painter(tester).audioData.samples, [0, 0, 0.8, 0.4]);
      await tester.pumpWidget(const SizedBox());
      expect(second.hasListener, isFalse);
      unawaited(first.close());
      unawaited(second.close());
    },
  );

  test('oval rotation rotates each segment rigidly around the center', () {
    Float32List points(double phase) {
      final canvas = RecordingCanvas();
      OvalWaveformPainter(
        audioData: const AudioData(samples: [1, 0.5, 0.2, 0.8]),
        color: Colors.blue,
        strokeWidth: 2,
        animateRotation: true,
        animationValue: phase,
      ).paint(canvas, const Size(300, 300));
      return canvas.points;
    }

    final start = points(0);
    final quarter = points(0.25);
    for (var i = 0; i < start.length; i += 2) {
      expect(quarter[i] - 150, closeTo(-(start[i + 1] - 150), 0.001));
      expect(quarter[i + 1] - 150, closeTo(start[i] - 150, 0.001));
    }
  });

  test(
    'radial waveforms stay within small rectangular bounds while rotating',
    () {
      for (final phase in [0.0, 0.125, 0.25, 0.5]) {
        for (final radialPainter in <VisualizerPainter>[
          CircularWaveformPainter(
            audioData: const AudioData(samples: [1, 1, 1, 1, 1, 1, 1, 1]),
            color: Colors.blue,
            strokeWidth: 2,
            animateRotation: true,
            animationValue: phase,
          ),
          OvalWaveformPainter(
            audioData: const AudioData(samples: [1, 1, 1, 1, 1, 1, 1, 1]),
            color: Colors.blue,
            strokeWidth: 2,
            animateRotation: true,
            animationValue: phase,
          ),
        ]) {
          final canvas = RecordingCanvas();
          radialPainter.paint(canvas, const Size(100, 80));
          for (var i = 0; i < canvas.points.length; i += 2) {
            expect(canvas.points[i], inInclusiveRange(1, 99));
            expect(canvas.points[i + 1], inInclusiveRange(1, 79));
          }
        }
      }
    },
  );
}
