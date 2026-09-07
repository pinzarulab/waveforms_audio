import 'dart:typed_data';

/// Lightweight streaming linear interpolation for normalized mono PCM.
///
/// Chunk boundaries do not affect output. Call [flush] at the end of a stream
/// to extend the final sample through its remaining duration. This resampler
/// is intended for visualization; it does not apply an anti-aliasing filter.
class PcmResampler {
  final int sourceSampleRate;
  final int targetSampleRate;
  int _position = 0;
  double? _previous;

  PcmResampler({
    required this.sourceSampleRate,
    required this.targetSampleRate,
  }) {
    if (sourceSampleRate <= 0 || targetSampleRate <= 0) {
      throw ArgumentError('Sample rates must be positive');
    }
  }

  Float32List addSamples(List<double> samples) {
    if (samples.isEmpty) return Float32List(0);
    final output = <double>[];
    // Integer phase avoids drift at fractional ratios such as 44.1 -> 48 kHz.
    final lastPosition = (samples.length - 1) * targetSampleRate;
    while (_position <= lastPosition) {
      final lower = (_position / targetSampleRate).floor();
      final fraction =
          (_position - lower * targetSampleRate) / targetSampleRate;
      final left = lower < 0 ? _previous! : samples[lower];
      final right = fraction == 0 ? left : samples[lower + 1];
      output.add(left + (right - left) * fraction);
      _position += sourceSampleRate;
    }
    _position -= samples.length * targetSampleRate;
    _previous = samples.last;
    return Float32List.fromList(output);
  }

  /// Emits the pending tail, then resets for an independent stream.
  Float32List flush() {
    final output = <double>[];
    if (_previous != null) {
      while (_position < 0) {
        output.add(_previous!);
        _position += sourceSampleRate;
      }
    }
    reset();
    return Float32List.fromList(output);
  }

  /// Discards the pending tail and interpolation history.
  void reset() {
    _position = 0;
    _previous = null;
  }
}
