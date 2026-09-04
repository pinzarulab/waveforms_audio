import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waveforms_audio/waveforms_audio.dart';
import 'package:waveforms_audio/src/painters/reactive_waveform_painter.dart';
import 'package:waveforms_audio/src/painters/shader_waveform_painter.dart';

Widget host(
  Stream<List<double>> stream, {
  bool reducedMotion = false,
  VoiceVisualizerStyle style = const VoiceVisualizerStyle.orb(),
  VoiceVisualizerRenderer renderer = VoiceVisualizerRenderer.canvas,
}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reducedMotion),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: ReactiveAudioVisualizer(
        audioStream: stream,
        sampleRate: 48000,
        style: style,
        renderer: renderer,
        motion: AudioMotionSettings.preset(AudioMotionPreset.voice)
            .copyWith(idleBreathing: 0),
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
        host(stream.stream, style: const VoiceVisualizerStyle.wave()),
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
    'GPU effect styles load the shared shader and keep a Canvas fallback',
    (tester) async {
      final stream = StreamController<List<double>>.broadcast();
      await tester.runAsync(precacheWaveformsAudioShaders);
      for (final style in const [
        VoiceVisualizerStyle.orb(),
        VoiceVisualizerStyle.wave(),
        VoiceVisualizerStyle.halo(),
        VoiceVisualizerStyle.ribbon(),
        VoiceVisualizerStyle.liquidOrb(),
        VoiceVisualizerStyle.pulseRings(),
        VoiceVisualizerStyle.voiceBloom(),
      ]) {
        await tester.pumpWidget(
          host(
            stream.stream,
            style: style,
            renderer: VoiceVisualizerRenderer.fragmentShader,
          ),
        );
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
        expect(
          tester.widget<CustomPaint>(find.byType(CustomPaint)).painter,
          isA<ShaderWaveformPainter>(),
          reason: style.kind.name,
        );
      }
      await tester.pumpWidget(
        host(
          stream.stream,
          style: const VoiceVisualizerStyle.liquidOrb(),
          renderer: VoiceVisualizerRenderer.canvas,
        ),
      );
      expect(painter(tester), isA<ReactiveWaveformPainter>());
      await tester.pumpWidget(const SizedBox());
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
