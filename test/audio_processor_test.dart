import 'package:flutter_test/flutter_test.dart';
import 'package:waveforms_audio/waveforms_audio.dart';

void main() {
  group('AudioProcessor Tests', () {
    test('extractPeaks downsamples correctly', () {
      final List<double> rawData = [
        0.1, -0.5, 0.2, // Bucket 1 max abs = 0.5
        0.8, -0.9, 0.4, // Bucket 2 max abs = 0.9
        0.1, 0.1, 0.1, // Bucket 3 max abs = 0.1
      ];

      final audioData = AudioProcessor.extractPeaks(
        rawData,
        3,
        normalize: false,
      );

      expect(audioData.samples.length, 3);
      expect(audioData.samples[0], 0.5);
      expect(audioData.samples[1], 0.9);
      expect(audioData.samples[2], 0.1);
      expect(audioData.maxAmplitude, 0.9);
    });

    test('extractPeaks normalizes correctly', () {
      final List<double> rawData = [
        0.1, -0.5, 0.2, // Bucket 1 max abs = 0.5
        0.8, -0.9, 0.4, // Bucket 2 max abs = 0.9
        0.1, 0.1, 0.1, // Bucket 3 max abs = 0.1
      ];

      final audioData = AudioProcessor.extractPeaks(
        rawData,
        3,
        normalize: true,
      );

      expect(audioData.samples.length, 3);
      // Normalized: each divided by 0.9
      expect(audioData.samples[0], closeTo(0.5 / 0.9, 0.001));
      expect(audioData.samples[1], closeTo(1.0, 0.001));
      expect(audioData.samples[2], closeTo(0.1 / 0.9, 0.001));
    });

    test('handles empty data', () {
      final audioData = AudioProcessor.extractPeaks([], 10);
      expect(audioData.samples.isEmpty, true);
    });
  });
}
