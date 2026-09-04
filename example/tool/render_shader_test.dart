import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waveforms_audio/src/audio/frequency_analyzer.dart';
import 'package:waveforms_audio/src/painters/reactive_waveform_painter.dart';
import 'package:waveforms_audio/src/painters/shader_waveform_painter.dart';
import 'package:waveforms_audio/src/shaders/visualizer_effects_shader.dart';
import 'package:waveforms_audio/waveforms_audio.dart';

void main() {
  testWidgets('render every GPU visualizer effect', (tester) async {
    tester.view.physicalSize = const Size(520, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final program = await tester.runAsync(VisualizerEffectsShaderProgram.load);
    final bands = List<double>.generate(
      32,
      (index) =>
          (0.25 +
                  math.sin(index * 0.48) * 0.12 +
                  math.exp(-math.pow((index - 9) / 5, 2)) * 0.55)
              .clamp(0.0, 1.0),
    );
    final frame = ValueNotifier(
      ReactiveFrame(
        AudioSpectrum(
          bands: bands,
          bass: 0.72,
          mids: 0.84,
          treble: 0.58,
          level: 0.68,
          peak: 0.9,
          voiceActivity: 0.76,
        ),
        1.7,
      ),
    );
    const gpuKinds = [
      VoiceVisualizerKind.orb,
      VoiceVisualizerKind.wave,
      VoiceVisualizerKind.halo,
      VoiceVisualizerKind.ribbon,
      VoiceVisualizerKind.liquidOrb,
      VoiceVisualizerKind.pulseRings,
      VoiceVisualizerKind.voiceBloom,
    ];
    for (final kind in gpuKinds) {
      final shader = VisualizerEffectsShaderInstance(program!);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xFF07100F),
            body: Center(
              child: RepaintBoundary(
                child: SizedBox.square(
                  dimension: 500,
                  child: CustomPaint(
                    painter: ShaderWaveformPainter(
                      animation: frame,
                      shader: shader,
                      style: VoiceVisualizerStyle(
                        kind: kind,
                        colors: const [Color(0xFF2979FF), Color(0xFF39E9FF)],
                        glow: 0.55,
                        density: 1.3,
                      ),
                      idleBreathing: 0.02,
                      reducedMotion: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: kind.name);
      await tester.pumpWidget(const SizedBox());
      shader.dispose();
    }

    frame.dispose();
  });
}
