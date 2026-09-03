import 'dart:math' as math;
import 'dart:typed_data';

/// Normalized frequency energy. Values are in the range 0–1.
class AudioSpectrum {
  final List<double> bands;
  final double bass;
  final double mids;
  final double treble;
  final double level;

  const AudioSpectrum({
    required this.bands,
    this.bass = 0,
    this.mids = 0,
    this.treble = 0,
    this.level = 0,
  });

  factory AudioSpectrum.silence(int bandCount) =>
      AudioSpectrum(bands: List.filled(bandCount, 0));
}

/// Stateful FFT analyzer for contiguous, mono PCM samples in the range -1–1.
///
/// [sampleRate] must match the source audio. The rolling window accepts arbitrary
/// chunk sizes. A Hann window reduces leakage; logarithmic bands and a fixed
/// decibel range retain loudness differences instead of normalizing every frame.
class FrequencyAnalyzer {
  final int sampleRate;
  final int fftSize;
  final int bandCount;
  late final Float64List _samples;
  late final Float64List _window;
  late final double _windowSum;
  int _writeIndex = 0;

  FrequencyAnalyzer({
    required this.sampleRate,
    this.fftSize = 2048,
    this.bandCount = 32,
  }) {
    if (sampleRate < 8000) {
      throw ArgumentError.value(
        sampleRate,
        'sampleRate',
        'Must be at least 8000',
      );
    }
    if (fftSize < 256 || fftSize > 8192 || (fftSize & (fftSize - 1)) != 0) {
      throw ArgumentError.value(
        fftSize,
        'fftSize',
        'Use a power of two from 256 to 8192',
      );
    }
    if (bandCount < 3 || bandCount > 128) {
      throw ArgumentError.value(
        bandCount,
        'bandCount',
        'Must be between 3 and 128',
      );
    }
    _samples = Float64List(fftSize);
    _window = Float64List.fromList(
      List.generate(
        fftSize,
        (i) => 0.5 - 0.5 * math.cos(2 * math.pi * i / (fftSize - 1)),
      ),
    );
    _windowSum = _window.reduce((a, b) => a + b);
  }

  double get minFrequency => 60;
  double get maxFrequency => math.min(16000, sampleRate / 2);

  /// Geometric center in Hz of each displayed band.
  List<double> get bandFrequencies => List.generate(
    bandCount,
    (i) =>
        minFrequency *
        math.pow(maxFrequency / minFrequency, (i + 0.5) / bandCount),
  );

  AudioSpectrum addSamples(List<double> chunk) {
    for (final sample in chunk) {
      _samples[_writeIndex] = sample.isFinite ? sample.clamp(-1.0, 1.0) : 0;
      _writeIndex = (_writeIndex + 1) % fftSize;
    }
    final real = Float64List(fftSize);
    final imaginary = Float64List(fftSize);
    final mean = _samples.reduce((a, b) => a + b) / fftSize;
    var sumSquares = 0.0;
    for (var i = 0; i < fftSize; i++) {
      final sample = _samples[(_writeIndex + i) % fftSize] - mean;
      sumSquares += sample * sample;
      real[i] = sample * _window[i];
    }
    final rms = math.sqrt(sumSquares / fftSize);
    // Suppress the noise floor; silence should settle, never fill the display.
    if (rms < 0.003) return AudioSpectrum.silence(bandCount);
    _fft(real, imaginary);
    final magnitudes = Float64List(fftSize ~/ 2 + 1);
    for (var i = 1; i < magnitudes.length; i++) {
      magnitudes[i] =
          2 *
          math.sqrt(real[i] * real[i] + imaginary[i] * imaginary[i]) /
          _windowSum;
    }
    double energy(double low, double high) {
      final first = math.max(1, (low * fftSize / sampleRate).ceil());
      final last = math.min(
        magnitudes.length - 1,
        (high * fftSize / sampleRate).floor(),
      );
      var peak = 0.0;
      if (first > last) {
        // Narrow bass bands can lie between FFT bins. Interpolate their center.
        final bin = math.sqrt(low * high) * fftSize / sampleRate;
        final left = bin.floor().clamp(0, magnitudes.length - 2);
        final t = (bin - left).clamp(0.0, 1.0);
        peak = magnitudes[left] * (1 - t) + magnitudes[left + 1] * t;
      } else {
        for (var i = first; i <= last; i++) {
          peak = math.max(peak, magnitudes[i]);
        }
      }
      final db = 20 * math.log(math.max(peak, 1e-6)) / math.ln10;
      return ((db + 60) / 54).clamp(0.0, 1.0);
    }

    final bands = List<double>.generate(bandCount, (i) {
      final low =
          minFrequency * math.pow(maxFrequency / minFrequency, i / bandCount);
      final high =
          minFrequency *
          math.pow(maxFrequency / minFrequency, (i + 1) / bandCount);
      return energy(low, high);
    });
    return AudioSpectrum(
      bands: bands,
      bass: energy(60, 250),
      mids: energy(250, 2000),
      treble: energy(2000, maxFrequency),
      level: (rms / 0.4).clamp(0.0, 1.0),
    );
  }

  void _fft(Float64List real, Float64List imaginary) {
    for (int i = 1, j = 0; i < fftSize; i++) {
      var bit = fftSize >> 1;
      for (; (j & bit) != 0; bit >>= 1) {
        j ^= bit;
      }
      j ^= bit;
      if (i < j) {
        final value = real[i];
        real[i] = real[j];
        real[j] = value;
      }
    }
    for (var length = 2; length <= fftSize; length <<= 1) {
      final angle = -2 * math.pi / length;
      final stepReal = math.cos(angle);
      final stepImaginary = math.sin(angle);
      for (var start = 0; start < fftSize; start += length) {
        var wr = 1.0;
        var wi = 0.0;
        for (var j = 0; j < length ~/ 2; j++) {
          final even = start + j;
          final odd = even + length ~/ 2;
          final tr = wr * real[odd] - wi * imaginary[odd];
          final ti = wr * imaginary[odd] + wi * real[odd];
          real[odd] = real[even] - tr;
          imaginary[odd] = imaginary[even] - ti;
          real[even] += tr;
          imaginary[even] += ti;
          final nextWr = wr * stepReal - wi * stepImaginary;
          wi = wr * stepImaginary + wi * stepReal;
          wr = nextWr;
        }
      }
    }
  }
}

/// Time-based attack/release envelope: quick response, unhurried settling.
/// Smoothing remains consistent across display refresh rates.
class SpectrumEnvelope {
  final Duration attack;
  final Duration release;
  AudioSpectrum value;

  SpectrumEnvelope({
    int bandCount = 32,
    this.attack = const Duration(milliseconds: 45),
    this.release = const Duration(milliseconds: 320),
  }) : value = AudioSpectrum.silence(bandCount) {
    if (attack <= Duration.zero || release <= Duration.zero) {
      throw ArgumentError('Attack and release must be positive');
    }
  }

  AudioSpectrum advance(AudioSpectrum target, Duration elapsed) {
    double follow(double from, double to) {
      final duration = to > from ? attack : release;
      final t =
          1 -
          math.exp(
            -math.max(0, elapsed.inMicroseconds) / duration.inMicroseconds,
          );
      final next = from + (to - from) * t;
      return next < 0.0005 ? 0 : next;
    }

    value = AudioSpectrum(
      bands: List.generate(
        target.bands.length,
        (i) => follow(
          i < value.bands.length ? value.bands[i] : 0,
          target.bands[i],
        ),
      ),
      bass: follow(value.bass, target.bass),
      mids: follow(value.mids, target.mids),
      treble: follow(value.treble, target.treble),
      level: follow(value.level, target.level),
    );
    return value;
  }
}
