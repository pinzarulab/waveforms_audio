import '../models/audio_data.dart';

class AudioProcessor {
  /// Downsamples a dense list of raw audio samples into a target number of buckets
  /// by finding the peak absolute value in each bucket.
  ///
  /// [rawSamples] is the input audio data (e.g. PCM float data from -1.0 to 1.0).
  /// [bucketCount] is the number of visual points you want to render.
  /// [normalize] if true, will scale the output samples so the highest peak is 1.0.
  static AudioData extractPeaks(
    List<double> rawSamples,
    int bucketCount, {
    bool normalize = true,
  }) {
    if (rawSamples.isEmpty || bucketCount <= 0) {
      return AudioData.empty();
    }

    if (rawSamples.length < bucketCount) {
      bucketCount = rawSamples.length;
    }

    final double bucketSize = rawSamples.length / bucketCount;
    final List<double> peaks = List<double>.filled(bucketCount, 0.0);
    double globalMax = 0.0;

    for (int i = 0; i < bucketCount; i++) {
      final int start = (i * bucketSize).floor();
      final int end = ((i + 1) * bucketSize).floor();

      double maxInBucket = 0.0;
      for (int j = start; j < end && j < rawSamples.length; j++) {
        final val = rawSamples[j].abs();
        if (val > maxInBucket) {
          maxInBucket = val;
        }
      }
      peaks[i] = maxInBucket;
      if (maxInBucket > globalMax) {
        globalMax = maxInBucket;
      }
    }

    if (normalize && globalMax > 0.0) {
      for (int i = 0; i < peaks.length; i++) {
        peaks[i] = peaks[i] / globalMax;
      }
    }

    return AudioData(samples: peaks, maxAmplitude: globalMax);
  }
}
