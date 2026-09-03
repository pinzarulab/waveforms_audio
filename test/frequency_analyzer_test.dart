import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:waveforms_audio/waveforms_audio.dart';

List<double> tone(
  double frequency, {
  int sampleRate = 48000,
  int count = 2048,
  double amplitude = 0.5,
}) => List.generate(
  count,
  (i) => amplitude * math.sin(2 * math.pi * frequency * i / sampleRate),
);

void main() {
  test('bass, voice, and treble tones excite their own frequency ranges', () {
    for (final rate in [16000, 44100, 48000]) {
      final analyzer = FrequencyAnalyzer(sampleRate: rate);
      final bass = analyzer.addSamples(tone(100, sampleRate: rate));
      expect(bass.bass, greaterThan(bass.mids + 0.3));
      expect(bass.bass, greaterThan(bass.treble + 0.3));
      final voice = analyzer.addSamples(tone(1000, sampleRate: rate));
      expect(voice.mids, greaterThan(voice.bass + 0.3));
      expect(voice.mids, greaterThan(voice.treble + 0.3));
      final air = analyzer.addSamples(tone(6000, sampleRate: rate));
      expect(air.treble, greaterThan(air.bass + 0.3));
      expect(air.treble, greaterThan(air.mids + 0.3));
      final peakIndex = air.bands.indexOf(air.bands.reduce(math.max));
      expect(analyzer.bandFrequencies[peakIndex], inInclusiveRange(5000, 7000));
    }
  });

  test('rolling FFT is independent of PCM chunk boundaries', () {
    final whole = FrequencyAnalyzer(sampleRate: 48000);
    final chunked = FrequencyAnalyzer(sampleRate: 48000);
    final input = tone(750, count: 4096);
    final expected = whole.addSamples(input);
    var result = AudioSpectrum.silence(32);
    for (var i = 0; i < input.length; i += 127) {
      result = chunked.addSamples(
        input.sublist(i, math.min(i + 127, input.length)),
      );
    }
    for (var i = 0; i < 32; i++) {
      expect(result.bands[i], closeTo(expected.bands[i], 1e-10));
    }
    expect(result.level, closeTo(expected.level, 1e-10));
  });

  test(
    'quiet sounds stay quieter; silence, DC, and nonfinite data stay quiet',
    () {
      final analyzer = FrequencyAnalyzer(sampleRate: 48000);
      final loud = analyzer.addSamples(tone(1000, amplitude: 0.5));
      final quiet = analyzer.addSamples(tone(1000, amplitude: 0.03));
      expect(quiet.mids, lessThan(loud.mids));
      expect(quiet.level, lessThan(loud.level));
      for (final input in [
        List<double>.filled(2048, 0),
        List<double>.filled(2048, 0.5),
        List<double>.generate(
          2048,
          (i) => i.isEven ? double.nan : double.infinity,
        ),
      ]) {
        final silence = analyzer.addSamples(input);
        expect(silence.level, 0);
        expect(silence.bands, everyElement(0));
      }
    },
  );

  test('attack is quick; release settles more slowly and consistently at different refresh rates', () {
    final target = AudioSpectrum(
      bands: List.filled(32, 1),
      bass: 1,
      mids: 1,
      treble: 1,
      level: 1,
    );
    final envelope = SpectrumEnvelope();
    final attack = envelope.advance(target, const Duration(milliseconds: 45));
    expect(attack.level, inInclusiveRange(0.62, 0.64));
    final release = envelope.advance(
      AudioSpectrum.silence(32),
      const Duration(milliseconds: 45),
    );
    expect(release.level, greaterThan(attack.level * 0.85));
    final slow = SpectrumEnvelope();
    final fast = SpectrumEnvelope();
    for (var i = 0; i < 30; i++) {
      slow.advance(target, const Duration(milliseconds: 16));
    }
    for (var i = 0; i < 60; i++) {
      fast.advance(target, const Duration(milliseconds: 8));
    }
    expect(slow.value.level, closeTo(fast.value.level, 1e-10));
    envelope.advance(AudioSpectrum.silence(32), const Duration(seconds: 5));
    expect(envelope.value.bands, everyElement(0));
  });

  test('invalid analyzer settings fail clearly', () {
    expect(() => FrequencyAnalyzer(sampleRate: 0), throwsArgumentError);
    expect(
      () => FrequencyAnalyzer(sampleRate: 48000, fftSize: 1000),
      throwsArgumentError,
    );
    expect(
      () => FrequencyAnalyzer(sampleRate: 48000, bandCount: 0),
      throwsArgumentError,
    );
  });
}
