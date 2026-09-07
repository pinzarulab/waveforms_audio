import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waveforms_audio/src/audio/frequency_analyzer.dart';
import 'package:waveforms_audio/src/painters/reactive_waveform_painter.dart';
import 'package:waveforms_audio/src/shaders/visualizer_effects_shader.dart';
import 'package:waveforms_audio/src/widgets/shader_visualizer_surface.dart';
import 'package:waveforms_audio/waveforms_audio.dart';

void main() {
  testWidgets('GPU renders intermediate stops for three and four colors', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final program = await VisualizerEffectsShaderProgram.load();
      final shader = VisualizerEffectsShaderInstance(program);
      addTearDown(shader.dispose);
      Future<List<int>> render(
        List<Color> colors, {
        VoiceVisualizerKind kind = VoiceVisualizerKind.orb,
      }) async {
        shader.update(
          size: const Size(64, 64),
          spectrum: AudioSpectrum(
            bands: List.filled(8, 0.5),
            bass: 0.5,
            mids: 0.5,
            treble: 0.5,
            level: 0.5,
            peak: 0.5,
            voiceActivity: 0.5,
          ),
          phase: 0,
          style: VoiceVisualizerStyle(kind: kind, colors: colors, glow: 0),
          idleBreathing: 0,
          reducedMotion: true,
        );
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 64, 64),
          Paint()..shader = shader.shader,
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(64, 64);
        final bytes = await image.toByteData();
        final result = bytes!.buffer.asUint8List().toList();
        image.dispose();
        picture.dispose();
        return result;
      }

      for (final kind in [
        VoiceVisualizerKind.halo,
        VoiceVisualizerKind.voiceBloom,
      ]) {
        final plain = await render([
          Colors.red,
          Colors.red,
          Colors.red,
          Colors.red,
        ], kind: kind);
        final middle = await render([
          Colors.red,
          Colors.green,
          Colors.blue,
          Colors.red,
        ], kind: kind);
        expect(
          middle,
          isNot(plain),
          reason: '${kind.name} must preserve interior stops',
        );
        expect(middle.where((value) => value > 0), isNotEmpty);
      }
      final solid = await render([Colors.red]);
      expect(await render([Colors.red, Colors.red]), solid);
      expect(await render([Colors.red, Colors.red, Colors.red]), solid);
      expect(
        await render([Colors.red, Colors.red, Colors.red, Colors.red]),
        solid,
      );
      final three = await render([Colors.red, Colors.green, Colors.red]);
      final four = await render([
        Colors.red,
        Colors.green,
        Colors.blue,
        Colors.red,
      ]);
      expect(three, isNot(solid));
      expect(four, isNot(three));
      expect(
        await render([Colors.red, Colors.red, Colors.blue, Colors.red]),
        isNot(four),
      );
      expect(
        await render([Colors.red, Colors.green, Colors.red, Colors.red]),
        isNot(four),
      );
      expect(
        await render([]),
        await render([const Color(0xFF72F5D1), const Color(0xFF6B8CFF)]),
      );
    });
  });

  testWidgets('liquid orb membranes and glow follow inactive color', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final program = await VisualizerEffectsShaderProgram.load();
      final shader = VisualizerEffectsShaderInstance(program);
      addTearDown(shader.dispose);
      Future<List<int>> render({
        required List<Color> colors,
        Color? inactiveColor,
        double energy = 0,
      }) async {
        shader.update(
          size: const Size(160, 160),
          spectrum: AudioSpectrum(
            bands: List.filled(8, energy),
            bass: energy,
            mids: energy,
            treble: energy,
            level: energy,
            peak: energy,
            voiceActivity: energy,
          ),
          phase: 0,
          style: VoiceVisualizerStyle.liquidOrb(
            colors: colors,
            inactiveColor: inactiveColor,
            glow: 0.5,
          ),
          idleBreathing: 0,
          reducedMotion: true,
        );
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 160, 160),
          Paint()..shader = shader.shader,
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(160, 160);
        final bytes = await image.toByteData();
        final result = bytes!.buffer.asUint8List().toList();
        image.dispose();
        picture.dispose();
        return result;
      }

      const active = [Color(0xFFFF0000), Color(0xFF0000FF)];
      const inactive = Color(0xFF00FF00);
      final resting = await render(colors: active, inactiveColor: inactive);
      final solidResting = await render(colors: [inactive]);
      // The whole image includes the outer membranes and their surrounding glow.
      expect(
        resting,
        solidResting,
        reason: 'No active color may leak into the idle membranes or glow',
      );
      expect(resting.where((value) => value > 0), isNotEmpty);
      final activeOnly = await render(colors: active);
      expect(resting, isNot(activeOnly));
      expect(
        await render(colors: active, inactiveColor: inactive, energy: 0.5),
        await render(colors: active, energy: 0.5),
        reason: 'Full activation restores the original active palette',
      );
      expect(
        await render(colors: active, inactiveColor: inactive, energy: 0.12),
        isNot(await render(colors: active, energy: 0.12)),
        reason: 'Partial activation still blends from the inactive color',
      );
    });
  });

  testWidgets('palettes longer than four stops retain Canvas fallback', (
    tester,
  ) async {
    final frame = ValueNotifier(
      ReactiveFrame(
        AudioSpectrum(
          bands: List.filled(8, 0),
          bass: 0,
          mids: 0,
          treble: 0,
          level: 0,
          peak: 0,
        ),
        0,
      ),
    );
    addTearDown(frame.dispose);
    await tester.runAsync(VisualizerEffectsShaderProgram.load);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ShaderVisualizerSurface(
          animation: frame,
          style: const VoiceVisualizerStyle(
            kind: VoiceVisualizerKind.orb,
            colors: [
              Colors.red,
              Colors.yellow,
              Colors.green,
              Colors.blue,
              Colors.purple,
            ],
          ),
          idleBreathing: 0,
          reducedMotion: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<CustomPaint>(find.byType(CustomPaint)).painter,
      isA<ReactiveWaveformPainter>(),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
