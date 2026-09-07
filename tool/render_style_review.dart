// Run with flutter test tool/render_style_review.dart.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waveforms_audio/src/audio/frequency_analyzer.dart';
import 'package:waveforms_audio/src/painters/reactive_waveform_painter.dart';
import 'package:waveforms_audio/src/shaders/visualizer_effects_shader.dart';
import 'package:waveforms_audio/waveforms_audio.dart';

void main() {
  testWidgets('render Canvas and GPU style comparison', (tester) async {
    await tester.runAsync(() async {
      final fontPath = Platform.environment['WAVEFORMS_PREVIEW_FONT'];
      if (fontPath != null) {
        await (FontLoader('Preview')..addFont(
              Future.value(
                ByteData.sublistView(await File(fontPath).readAsBytes()),
              ),
            ))
            .load();
      }
      final program = await VisualizerEffectsShaderProgram.load();
      const styles = [
        VoiceVisualizerStyle.wave(),
        VoiceVisualizerStyle.ribbon(),
        VoiceVisualizerStyle.halo(),
        VoiceVisualizerStyle.voiceBloom(),
        VoiceVisualizerStyle.bars(),
        VoiceVisualizerStyle.mirrorSpectrum(),
      ];
      final frame = ValueNotifier(
        ReactiveFrame(
          AudioSpectrum(
            bands: List.generate(
              32,
              (i) => (0.2 + math.sin(i * 0.7).abs() * 0.6),
            ),
            bass: 0.65,
            mids: 0.5,
            treble: 0.4,
            level: 0.7,
            peak: 0.8,
            voiceActivity: 0.6,
          ),
          1.8,
        ),
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(const Color(0xFF0B1020), BlendMode.src);
      final shaders = <VisualizerEffectsShaderInstance>[];
      for (var row = 0; row < styles.length; row++) {
        for (var col = 0; col < 2; col++) {
          final style = styles[row].copyWith(
            colors: const [
              Color(0xFF4B8CFF),
              Color(0xFF62E5DF),
              Color(0xFFAE87FF),
              Color(0xFFFFA0D2),
            ],
          );
          final label = TextPainter(
            text: TextSpan(
              text:
                  '${style.kind.name} · ${col == 0 || row > 3 ? "Canvas" : "GPU"}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'Preview',
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          label.paint(canvas, Offset(col * 420 + 20, row * 250 + 10));
          label.dispose();
          canvas.save();
          canvas.translate(col * 420 + 10, row * 250 + 35);
          const size = Size(400, 210);
          if (col == 0 || row > 3) {
            ReactiveWaveformPainter(
              animation: frame,
              style: style,
            ).paint(canvas, size);
          } else {
            final shader = VisualizerEffectsShaderInstance(program);
            shaders.add(shader);
            shader.update(
              size: size,
              spectrum: frame.value.spectrum,
              phase: frame.value.phase,
              style: style,
              idleBreathing: 0,
              reducedMotion: false,
            );
            canvas.drawRect(
              Offset.zero & size,
              Paint()..shader = shader.shader,
            );
          }
          canvas.restore();
        }
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(840, 1500);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build').create(recursive: true);
      await File('build/style-review.png')
          .writeAsBytes(png!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
      for (final shader in shaders) {
        shader.dispose();
      }
      frame.dispose();
    });
  });
}
