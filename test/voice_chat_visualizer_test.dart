import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waveforms_audio/waveforms_audio.dart';

void main() {
  test('PCM16 decoding preserves signed samples and split byte boundaries', () {
    final decoder = Pcm16Decoder();
    expect(decoder.addBytes(Uint8List.fromList([0, 128, 255])), [-1]);
    expect(decoder.addBytes(Uint8List(0)), isEmpty);
    expect(decoder.addBytes(Uint8List.fromList([127, 0, 0, 0, 64])), [
      32767 / 32768,
      0,
      0.5,
    ]);
  });

  testWidgets(
    'speaker colors transition smoothly without replacing audio state',
    (tester) async {
      final stream = StreamController<List<double>>.broadcast();
      Widget host(VoiceChatSpeaker speaker, {bool reducedMotion = false}) =>
          MediaQuery(
            data: MediaQueryData(disableAnimations: reducedMotion),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: VoiceChatVisualizer(
                audioStream: stream.stream,
                sampleRate: 48000,
                speaker: speaker,
              ),
            ),
          );
      ReactiveWaveformPainter painter() =>
          tester.widget<CustomPaint>(find.byType(CustomPaint)).painter!
              as ReactiveWaveformPainter;
      await tester.pumpWidget(host(VoiceChatSpeaker.local));
      final animation = painter().animation;
      expect(painter().color, VoiceChatSpeaker.local.color);
      expect(painter().secondaryColor, VoiceChatSpeaker.local.secondaryColor);
      await tester.pumpWidget(host(VoiceChatSpeaker.remote));
      await tester.pump(const Duration(milliseconds: 120));
      expect(painter().color, isNot(VoiceChatSpeaker.local.color));
      expect(painter().color, isNot(VoiceChatSpeaker.remote.color));
      expect(identical(painter().animation, animation), isTrue);
      await tester.pump(const Duration(milliseconds: 120));
      expect(painter().color, VoiceChatSpeaker.remote.color);
      expect(painter().secondaryColor, VoiceChatSpeaker.remote.secondaryColor);
      await tester.pumpWidget(
        host(VoiceChatSpeaker.local, reducedMotion: true),
      );
      await tester.pump();
      expect(painter().color, VoiceChatSpeaker.local.color);
      await tester.pumpWidget(const SizedBox());
      expect(stream.hasListener, isFalse);
      unawaited(stream.close());
    },
  );

  testWidgets('local and remote broadcast sources can alternate repeatedly', (
    tester,
  ) async {
    final local = StreamController<List<double>>.broadcast();
    final remote = StreamController<List<double>>.broadcast();
    for (final speaker in [
      VoiceChatSpeaker.local,
      VoiceChatSpeaker.remote,
      VoiceChatSpeaker.local,
    ]) {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: VoiceChatVisualizer(
            audioStream: speaker == VoiceChatSpeaker.local
                ? local.stream
                : remote.stream,
            sampleRate: speaker == VoiceChatSpeaker.local ? 48000 : 24000,
            speaker: speaker,
          ),
        ),
      );
      expect(local.hasListener, speaker == VoiceChatSpeaker.local);
      expect(remote.hasListener, speaker == VoiceChatSpeaker.remote);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    unawaited(local.close());
    unawaited(remote.close());
  });
}
