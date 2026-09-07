import 'package:flutter_test/flutter_test.dart';
import 'package:example/main.dart';
import 'package:waveforms_audio/src/audio/frequency_analyzer.dart';

void main() {
  test('full mix excites bass, voice and air together without clipping', () {
    final analyzer = FrequencyAnalyzer(sampleRate: 48000);
    var simultaneousFrames = 0;
    for (var chunk = 0; chunk < 250; chunk++) {
      final samples = List<double>.generate(
        768,
        (i) => demoSignalSample(DemoSignal.fullMix, (chunk * 768 + i) / 48000),
      );
      expect(
        samples.every((sample) => sample.isFinite && sample.abs() < 1),
        isTrue,
      );
      final spectrum = analyzer.addSamples(samples);
      if (spectrum.bass > 0.1 && spectrum.mids > 0.1 && spectrum.treble > 0.1) {
        simultaneousFrames++;
      }
    }
    expect(
      simultaneousFrames,
      greaterThan(125),
      reason: 'All three ranges should react together through most of the demo',
    );
  });
}
