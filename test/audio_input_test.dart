import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waveforms_audio/waveforms_audio.dart';

void main() {
  test('PCM16 supports endian, stereo downmixing, and channel selection', () {
    final stereo = ByteData(8)
      ..setInt16(0, 32767, Endian.little)
      ..setInt16(2, -32768, Endian.little)
      ..setInt16(4, 16384, Endian.little)
      ..setInt16(6, 8192, Endian.little);
    final average = AudioDecoder(
      const AudioFormat(
        encoding: AudioEncoding.pcm16,
        sampleRate: 48000,
        channels: 2,
      ),
    );
    expect(
      average.addBytes(stereo.buffer.asUint8List().sublist(0, 3)),
      isEmpty,
    );
    final mixed = average.addBytes(stereo.buffer.asUint8List().sublist(3));
    expect(mixed[0], closeTo(-1 / 65536, 1e-6));
    expect(mixed[1], closeTo(0.375, 1e-6));

    final right = AudioDecoder(
      const AudioFormat(
        encoding: AudioEncoding.pcm16,
        sampleRate: 48000,
        channels: 2,
        channel: 1,
      ),
    ).addBytes(stereo.buffer.asUint8List());
    expect(right, [-1, 0.25]);

    final bigEndian = ByteData(2)..setInt16(0, 16384, Endian.big);
    expect(
      AudioDecoder(
        const AudioFormat(
          encoding: AudioEncoding.pcm16,
          sampleRate: 16000,
          endian: Endian.big,
        ),
      ).addBytes(bigEndian.buffer.asUint8List()),
      [0.5],
    );
  });

  test('PCM24 and Float32 decode, clamp, and accept base64', () {
    final pcm24 = Uint8List.fromList([0x00, 0x00, 0x80, 0xFF, 0xFF, 0x7F]);
    final decoder = AudioDecoder(
      const AudioFormat(encoding: AudioEncoding.pcm24, sampleRate: 48000),
    );
    expect(decoder.addBase64(base64Encode(pcm24)), [
      -1,
      closeTo(8388607 / 8388608, 1e-7),
    ]);

    final floats = ByteData(12)
      ..setFloat32(0, -0.25, Endian.big)
      ..setFloat32(4, 1.5, Endian.big)
      ..setFloat32(8, double.nan, Endian.big);
    expect(
      AudioDecoder(
        const AudioFormat(
          encoding: AudioEncoding.float32,
          sampleRate: 24000,
          endian: Endian.big,
        ),
      ).addBytes(floats.buffer.asUint8List()),
      [-0.25, 1, 0],
    );
  });

  test('controller accepts bytes, base64, and normalized samples', () async {
    final controller = ReactiveAudioController(
      format: const AudioFormat(
        encoding: AudioEncoding.pcm16,
        sampleRate: 48000,
      ),
    );
    final received = <List<double>>[];
    final subscription = controller.stream.listen(received.add);
    controller.addBytes([0, 64]);
    controller.addBase64(base64Encode([0, 192]));
    controller.addSamples([2, -2, double.nan]);
    await Future<void>.delayed(Duration.zero);
    expect(received[0], [0.5]);
    expect(received[1], [-0.5]);
    expect(received[2], [1, -1, 0]);
    await subscription.cancel();
    await controller.close();
    expect(() => controller.addBytes([0, 0]), throwsStateError);
  });

  testWidgets('controller drives a voice-chat visualizer directly', (
    tester,
  ) async {
    final controller = ReactiveAudioController(
      format: const AudioFormat(
        encoding: AudioEncoding.pcm16,
        sampleRate: 48000,
      ),
    );
    var voiceActivity = 0.0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: VoiceChatVisualizer(
          controller: controller,
          speaker: VoiceChatSpeaker.remote,
          style: const VoiceVisualizerStyle.minimalLine(),
          onVoiceActivity: (value) => voiceActivity = value,
        ),
      ),
    );
    controller.addSamples(
      List<double>.generate(
        2048,
        (i) => math.sin(i * math.pi * 2 * 700 / 48000) * 0.3,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    expect(voiceActivity, greaterThan(0));
    await tester.pumpWidget(const SizedBox());
    await controller.dispose();
  });
}
