import 'dart:collection';

/// An immutable snapshot of normalized waveform samples.
class AudioData {
  /// The normalized amplitude values (usually between 0.0 and 1.0 or -1.0 to 1.0).
  /// These are pre-processed to match the number of visual segments to be drawn.
  final UnmodifiableListView<double> samples;

  /// The maximum amplitude found in the original dataset before normalization.
  final double maxAmplitude;

  /// Copies [samples] into an unmodifiable snapshot without normalizing them.
  ///
  /// [maxAmplitude] defaults to 1 and must be finite and non-negative, otherwise
  /// throws [ArgumentError]. Keep sample values finite for predictable rendering.
  AudioData({required Iterable<double> samples, this.maxAmplitude = 1.0})
    : samples = UnmodifiableListView<double>(List<double>.of(samples)) {
    if (!maxAmplitude.isFinite || maxAmplitude < 0) {
      throw ArgumentError.value(
        maxAmplitude,
        'maxAmplitude',
        'Must be finite and non-negative',
      );
    }
  }

  /// Factory for an empty data set.
  factory AudioData.empty() => AudioData(samples: const []);
}
