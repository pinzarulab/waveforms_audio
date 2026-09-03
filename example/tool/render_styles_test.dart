// Render a visual review sheet with:
// flutter test tool/render_styles_test.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waveforms_audio/waveforms_audio.dart';

void main() {
  testWidgets('render active and resting style gallery', (tester) async {
    tester.view.physicalSize = const Size(1200, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = Platform.environment['WAVEFORMS_PREVIEW_FONT'];
    if (font != null) {
      await (FontLoader('Preview')..addFont(
            Future.value(ByteData.sublistView(File(font).readAsBytesSync())),
          ))
          .load();
    }
    final bands = List.generate(32, (i) {
      final x = i / 31;
      return (0.85 * math.exp(-math.pow((x - 0.18) / 0.12, 2)) +
              0.65 * math.exp(-math.pow((x - 0.52) / 0.16, 2)) +
              0.5 * math.exp(-math.pow((x - 0.86) / 0.09, 2)))
          .clamp(0.0, 1.0);
    });
    final active = ValueNotifier(
      ReactiveFrame(
        AudioSpectrum(
          bands: bands,
          level: 0.7,
          bass: 0.9,
          mids: 0.8,
          treble: 0.65,
        ),
        1.8,
      ),
    );
    final idle = ValueNotifier(ReactiveFrame(AudioSpectrum.silence(32), 0));
    const palettes = [
      [Color(0xFF2979FF), Color(0xFF39E9FF)],
      [Color(0xFF9B7BFF), Color(0xFFF28DCE)],
      [Color(0xFF2979FF), Color(0xFF39E9FF)],
      [Color(0xFF23D997), Color(0xFFB8F76B)],
      [Color(0xFF9B7BFF), Color(0xFFF28DCE)],
      [Color(0xFFFF453A), Color(0xFFFFAA33)],
    ];
    const labels = [
      'Orb',
      'Wave',
      'Spectrum',
      'Upward bars',
      'Voice bars',
      'Halo',
    ];
    const key = ValueKey('gallery');
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Preview'),
          home: Scaffold(
            backgroundColor: const Color(0xFF0B1212),
            body: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Six ways to feel sound.',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Active above. Resting below. Same palette by default; idle color is optional.',
                    style: TextStyle(color: Color(0xFF9AAEAB), fontSize: 15),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 3,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.08,
                      children: [
                        for (
                          var i = 0;
                          i < ReactiveVisualizerStyle.values.length;
                          i++
                        )
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF142020),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF293835),
                              ),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${(i + 1).toString().padLeft(2, '0')}  ${labels[i]}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Expanded(
                                  child: SizedBox.expand(
                                    child: CustomPaint(
                                      painter: ReactiveWaveformPainter(
                                        animation: active,
                                        style:
                                            ReactiveVisualizerStyle.values[i],
                                        color: palettes[i][0],
                                        secondaryColor: palettes[i][1],
                                      ),
                                    ),
                                  ),
                                ),
                                const Divider(color: Color(0xFF293835)),
                                SizedBox(
                                  height: 56,
                                  child: Row(
                                    children: [
                                      const Text(
                                        'RESTING',
                                        style: TextStyle(
                                          color: Color(0xFF93A19D),
                                          fontSize: 9,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      Expanded(
                                        child: SizedBox.expand(
                                          child: CustomPaint(
                                            painter: ReactiveWaveformPainter(
                                              animation: idle,
                                              style: ReactiveVisualizerStyle
                                                  .values[i],
                                              color: palettes[i][0],
                                              secondaryColor: palettes[i][1],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('build/visual-preview')
        ..createSync(recursive: true);
      File('${directory.path}/styles-gallery.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox());
    active.dispose();
    idle.dispose();
  });
}
