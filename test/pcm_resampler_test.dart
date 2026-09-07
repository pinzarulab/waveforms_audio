import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:waveforms_audio/waveforms_audio.dart';

void main() {
  test('linear interpolation and tail extension', () {
    final resampler = PcmResampler(
      sourceSampleRate: 16000,
      targetSampleRate: 48000,
    );
    expect(resampler.addSamples([0, 0.75]), [0, 0.25, 0.5, 0.75]);
    expect(resampler.flush(), [0.75, 0.75]);
    expect(resampler.flush(), isEmpty);
    expect(resampler.addSamples([-1]), [-1]);
    resampler.reset();
    expect(resampler.flush(), isEmpty);
  });

  for (final source in [16000, 24000, 44100, 48000]) {
    for (final target in [16000, 24000, 44100, 48000]) {
      test('$source -> $target preserves timing and chunk continuity', () {
        final input = List<double>.generate(
          source,
          (i) => math.sin(2 * math.pi * 400 * i / source),
        );
        final whole = PcmResampler(
          sourceSampleRate: source,
          targetSampleRate: target,
        );
        final expected = [...whole.addSamples(input), ...whole.flush()];
        final chunked = PcmResampler(
          sourceSampleRate: source,
          targetSampleRate: target,
        );
        final actual = <double>[];
        for (var i = 0; i < input.length;) {
          final end = math.min(input.length, i + (i % 113) + 1);
          actual.addAll(chunked.addSamples(input.sublist(i, end)));
          expect(chunked.addSamples([]), isEmpty);
          i = end;
        }
        actual.addAll(chunked.flush());
        expect(actual, expected);
        expect(actual.length, target);
        // Low-frequency tone retains pitch and amplitude after conversion.
        for (var i = 0; i < actual.length - 3; i += 79) {
          expect(
            actual[i],
            closeTo(math.sin(2 * math.pi * 400 * i / target), 0.005),
          );
        }
      });
    }
  }

  test('rejects invalid sample rates', () {
    expect(
      () => PcmResampler(sourceSampleRate: 0, targetSampleRate: 48000),
      throwsArgumentError,
    );
    expect(
      () => PcmResampler(sourceSampleRate: 16000, targetSampleRate: -1),
      throwsArgumentError,
    );
  });
}
