// Export PNG frames: flutter test tool/render_readme_gifs.dart
// Encode GIFs: python3 tool/encode_readme_gifs.py (requires Pillow).
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waveforms_audio/src/audio/frequency_analyzer.dart';
import 'package:waveforms_audio/src/painters/reactive_waveform_painter.dart';
import 'package:waveforms_audio/src/shaders/visualizer_effects_shader.dart';
import 'package:waveforms_audio/src/widgets/shader_visualizer_surface.dart';
import 'package:waveforms_audio/waveforms_audio.dart';

void main() {
  testWidgets('export animated README style previews', (tester) async {
    await tester.runAsync(() async {
      final program = await VisualizerEffectsShaderProgram.load();
      const styles = [
        VoiceVisualizerStyle.orb(),
        VoiceVisualizerStyle.liquidOrb(),
        VoiceVisualizerStyle.wave(),
        VoiceVisualizerStyle.ribbon(),
        VoiceVisualizerStyle.bars(),
        VoiceVisualizerStyle.upwardBars(),
        VoiceVisualizerStyle.voiceBars(),
        VoiceVisualizerStyle.mirrorSpectrum(),
        VoiceVisualizerStyle.halo(),
        VoiceVisualizerStyle.voiceBloom(),
        VoiceVisualizerStyle.pulseRings(),
        VoiceVisualizerStyle.dotSpectrum(),
        VoiceVisualizerStyle.capsuleBars(),
        VoiceVisualizerStyle.minimalLine(),
      ];
      const size = Size(320, 200);
      for (final preset in styles) {
        final style = preset.copyWith(colors: const [
          Color(0xFF4B8CFF),
          Color(0xFF62E5DF),
          Color(0xFFAE87FF),
          Color(0xFFFFA0D2),
        ]);
        final directory = Directory('build/readme-frames/${style.kind.name}');
        await directory.create(recursive: true);
        final shader = supportsFragmentShader(style.kind)
            ? VisualizerEffectsShaderInstance(program)
            : null;
        final animation =
            ValueNotifier(ReactiveFrame(AudioSpectrum.silence(32), 0));
        try {
          for (var frame = 0; frame < 50; frame++) {
            // Periodic synthetic energy and phase make each four-second loop
            // seamless. No microphone, recording, or model-generated imagery.
            final t = frame / 50 * math.pi * 2;
            final pulse = 0.5 - 0.5 * math.cos(t);
            final bands = List<double>.generate(32, (i) {
              final x = i / 31;
              final voice =
                  math.exp(-math.pow((x - 0.35 - 0.1 * math.sin(t)) / 0.22, 2));
              return (0.06 +
                      pulse * (0.25 + voice * 0.55) +
                      0.08 * (1 + math.sin(x * 12 + t)))
                  .clamp(0.0, 1.0);
            });
            final spectrum = AudioSpectrum(
              bands: bands,
              bass: 0.08 + pulse * 0.75,
              mids: 0.06 + pulse * 0.62,
              treble: 0.05 + pulse * 0.48,
              level: 0.08 + pulse * 0.68,
              peak: 0.12 + pulse * 0.73,
              voiceActivity: pulse * 0.8,
            );
            final phase = 1.8 + math.sin(t) * 1.3;
            animation.value = ReactiveFrame(spectrum, phase);
            final recorder = ui.PictureRecorder();
            final canvas = Canvas(recorder);
            canvas.drawColor(const Color(0xFF0B1020), BlendMode.src);
            // A small inset keeps horizontal ends away from the image boundary.
            canvas.translate(12, 8);
            final content = Size(size.width - 24, size.height - 16);
            if (shader == null) {
              ReactiveWaveformPainter(animation: animation, style: style)
                  .paint(canvas, content);
            } else {
              shader.update(
                  size: content,
                  spectrum: spectrum,
                  phase: phase,
                  style: style,
                  idleBreathing: 0,
                  reducedMotion: false);
              canvas.drawRect(
                  Offset.zero & content, Paint()..shader = shader.shader);
            }
            final picture = recorder.endRecording();
            final image =
                await picture.toImage(size.width.toInt(), size.height.toInt());
            try {
              final png =
                  await image.toByteData(format: ui.ImageByteFormat.png);
              await File(
                      '${directory.path}/${frame.toString().padLeft(3, '0')}.png')
                  .writeAsBytes(png!.buffer.asUint8List());
            } finally {
              image.dispose();
              picture.dispose();
            }
          }
        } finally {
          animation.dispose();
          shader?.dispose();
        }
      }
    });
  }, timeout: const Timeout(Duration(minutes: 3)));
}
