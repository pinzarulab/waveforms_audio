class AudioData {
  /// The normalized amplitude values (usually between 0.0 and 1.0 or -1.0 to 1.0).
  /// These are pre-processed to match the number of visual segments to be drawn.
  final List<double> samples;

  /// The maximum amplitude found in the original dataset before normalization.
  final double maxAmplitude;

  const AudioData({required this.samples, this.maxAmplitude = 1.0});

  /// Factory for an empty data set.
  factory AudioData.empty() => const AudioData(samples: [], maxAmplitude: 1.0);
}
