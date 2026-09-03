import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waveforms_audio/waveforms_audio.dart';
import 'package:example/main.dart';

void main() {
  testWidgets(
    'frequency showcase supports styles, sources, silence, and narrow screens',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final previewDirectory = Platform.environment['WAVEFORMS_PREVIEW_DIR'];
      final fontPath = Platform.environment['WAVEFORMS_PREVIEW_FONT'];
      if (fontPath != null) {
        final loader = FontLoader('sans-serif')
          ..addFont(
            Future.value(
              ByteData.sublistView(File(fontPath).readAsBytesSync()),
            ),
          );
        await loader.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
      }
      const previewKey = ValueKey('preview');
      await tester.pumpWidget(
        const RepaintBoundary(key: previewKey, child: MyApp()),
      );
      expect(find.text('Sound, with a pulse.'), findsOneWidget);
      await tester.ensureVisible(find.text('Demo signal'));
      await tester.tap(find.text('Demo signal'));
      await tester.pump();
      expect(find.byType(ReactiveAudioVisualizer), findsOneWidget);
      expect(
        tester
            .widget<ReactiveAudioVisualizer>(
              find.byType(ReactiveAudioVisualizer),
            )
            .inactiveColor,
        isNull,
      );
      for (final style in [
        'Orb',
        'Wave',
        'Spectrum',
        'Up bars',
        'Voice bars',
        'Halo',
      ]) {
        await tester.ensureVisible(find.text(style));
        await tester.tap(find.text(style));
        for (var i = 0; i < 70; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(tester.takeException(), isNull);
        if (previewDirectory != null) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(previewKey),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            Directory(previewDirectory).createSync(recursive: true);
            File('$previewDirectory/${style.toLowerCase()}.png')
                .writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
          if (style == 'Orb' &&
              Platform.environment['WAVEFORMS_RECORD'] == '1') {
            for (var frame = 0; frame < 60; frame++) {
              await tester.pump(const Duration(milliseconds: 40));
              await tester.runAsync(() async {
                final image = await boundary.toImage(pixelRatio: 1);
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final directory = Directory('$previewDirectory/frames')
                  ..createSync(recursive: true);
                File(
                  '${directory.path}/frame-${frame.toString().padLeft(3, '0')}.png',
                ).writeAsBytesSync(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
          }
        }
      }
      await tester.ensureVisible(find.text('Colors'));
      await tester.tap(find.text('Colors'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.text('Emerald'));
      await tester.tap(find.text('Emerald'));
      await tester.ensureVisible(find.text('Rose idle'));
      await tester.tap(find.text('Rose idle'));
      await tester.pump();
      final visualizer = tester.widget<ReactiveAudioVisualizer>(
        find.byType(ReactiveAudioVisualizer),
      );
      expect(visualizer.color, const Color(0xFF23D997));
      expect(visualizer.inactiveColor, const Color(0xFFAC768C));
      await tester.ensureVisible(find.text('Keep active color'));
      await tester.tap(find.text('Keep active color'));
      await tester.pump();
      expect(
        tester
            .widget<ReactiveAudioVisualizer>(
              find.byType(ReactiveAudioVisualizer),
            )
            .inactiveColor,
        isNull,
      );
      for (final source in ['Bass', 'Air', 'Voice']) {
        await tester.ensureVisible(find.text(source));
        await tester.tap(find.text(source));
        for (var i = 0; i < 15; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(tester.takeException(), isNull);
      }
      await tester.ensureVisible(find.byTooltip('Pause signal'));
      await tester.tap(find.byTooltip('Pause signal'));
      await tester.pumpAndSettle(const Duration(milliseconds: 16));
      expect(find.byTooltip('Resume signal'), findsOneWidget);
      tester.view.physicalSize = const Size(320, 720);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
