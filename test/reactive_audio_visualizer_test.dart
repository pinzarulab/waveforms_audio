import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waveforms_audio/waveforms_audio.dart';

Widget host(
  Stream<List<double>> stream, {
  bool reducedMotion = false,
  ReactiveVisualizerStyle style = ReactiveVisualizerStyle.orb,
}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reducedMotion),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: ReactiveAudioVisualizer(
        audioStream: stream,
        sampleRate: 48000,
        style: style,
      ),
    ),
  ),
);

ReactiveWaveformPainter painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byType(CustomPaint)).painter!
        as ReactiveWaveformPainter;

Future<void> frames(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  final bass = List.generate(
    2048,
    (i) => math.sin(i * 2 * math.pi * 100 / 48000) * 0.6,
  );

  testWidgets(
    'reacts to PCM, preserves envelope across styles, settles when input stops',
    (tester) async {
      final stream = StreamController<List<double>>();
      await tester.pumpWidget(host(stream.stream));
      stream.add(bass);
      await tester.pump();
      await frames(tester, 8);
      expect(painter(tester).animation.value.spectrum.bass, greaterThan(0.5));
      final before = painter(tester).animation.value.spectrum.bass;
      await tester.pumpWidget(
        host(stream.stream, style: ReactiveVisualizerStyle.wave),
      );
      expect(painter(tester).animation.value.spectrum.bass, before);
      await frames(tester, 220);
      expect(painter(tester).animation.value.spectrum.bands, everyElement(0));
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(const SizedBox());
      expect(stream.hasListener, isFalse);
      unawaited(stream.close());
    },
  );

  testWidgets(
    'reduced motion disables continuous motion and stream replacement clears old audio',
    (tester) async {
      final first = StreamController<List<double>>();
      final second = StreamController<List<double>>();
      await tester.pumpWidget(host(first.stream, reducedMotion: true));
      first.add(bass);
      await tester.pump();
      await tester.pump();
      expect(painter(tester).animation.value.spectrum.bass, greaterThan(0.5));
      expect(painter(tester).animation.value.phase, 0);
      expect(painter(tester).reducedMotion, isTrue);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(host(second.stream, reducedMotion: true));
      expect(first.hasListener, isFalse);
      expect(painter(tester).animation.value.spectrum.level, 0);
      await tester.pumpWidget(const SizedBox());
      expect(second.hasListener, isFalse);
      unawaited(first.close());
      unawaited(second.close());
    },
  );
}
