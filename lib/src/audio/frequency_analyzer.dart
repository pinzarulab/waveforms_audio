import 'dart:math' as math;
import 'dart:typed_data';

import 'audio_motion.dart';

/// Normalized frequency energy. Values are in the range 0–1.
class AudioSpectrum {
  final List<double> bands;
  final double bass;
  final double mids;
  final double treble;
  final double level;
  final double peak;
  final double voiceActivity;

  const AudioSpectrum({
    required this.bands,
    this.bass = 0,
    this.mids = 0,
    this.treble = 0,
    this.level = 0,
    this.peak = 0,
    this.voiceActivity = 0,
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
  final double noiseGate;
  final bool adaptiveGain;
  late final Float64List _samples;
  late final Float64List _window;
  late final double _windowSum;
  int _writeIndex = 0;
  double _gainReference = 0.08;

  FrequencyAnalyzer({
    required this.sampleRate,
    this.fftSize = 2048,
    this.bandCount = 32,
    this.noiseGate = 0.003,
    this.adaptiveGain = false,
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
    if (!noiseGate.isFinite || noiseGate < 0 || noiseGate >= 1) {
      throw ArgumentError.value(noiseGate, 'noiseGate', 'Must be from 0 to 1');
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
    if (rms < noiseGate) return AudioSpectrum.silence(bandCount);
    var gain = 1.0;
    if (adaptiveGain) {
      // Follow loudness slowly. Quiet voices become visible without flattening
      // the dynamics inside each phrase.
      _gainReference +=
          (rms - _gainReference) * (rms > _gainReference ? 0.08 : 0.015);
      gain = (0.18 / math.max(_gainReference, noiseGate)).clamp(0.55, 7.0);
    }
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
      return (((db + 60) / 54) * math.sqrt(gain)).clamp(0.0, 1.0);
    }

    final bands = List<double>.generate(bandCount, (i) {
      final low =
          minFrequency * math.pow(maxFrequency / minFrequency, i / bandCount);
      final high =
          minFrequency *
          math.pow(maxFrequency / minFrequency, (i + 1) / bandCount);
      return energy(low, high);
    });
    final bass = energy(60, 250);
    final mids = energy(250, 2000);
    final treble = energy(2000, maxFrequency);
    final level = (rms * gain / 0.4).clamp(0.0, 1.0);
    final voiceActivity =
        ((mids * 0.72 + level * 0.28) - bass * 0.10 - treble * 0.04).clamp(
          0.0,
          1.0,
        );
    return AudioSpectrum(
      bands: bands,
      bass: bass,
      mids: mids,
      treble: treble,
      level: level,
      peak: level,
      voiceActivity: voiceActivity,
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
  final AudioMotionSettings motion;
  AudioSpectrum value;
  Duration _peakHeld = Duration.zero;

  SpectrumEnvelope({
    int bandCount = 32,
    AudioMotionSettings? motion,
    Duration? attack,
    Duration? release,
  }) : motion =
           motion ??
           AudioMotionSettings.preset(AudioMotionPreset.voice).copyWith(
             bassAttack: attack,
             midsAttack: attack,
             trebleAttack: attack,
             levelAttack: attack,
             bassRelease: release,
             midsRelease: release,
             trebleRelease: release,
             levelRelease: release,
           ),
       value = AudioSpectrum.silence(bandCount);

  AudioSpectrum advance(AudioSpectrum target, Duration elapsed) {
    double follow(double from, double to, Duration attack, Duration release) {
      final duration = to > from ? attack : release;
      final t =
          1 -
          math.exp(
            -math.max(0, elapsed.inMicroseconds) / duration.inMicroseconds,
          );
      final next = from + (to - from) * t;
      return next < 0.0005 ? 0 : next;
    }

    final bass = follow(
      value.bass,
      target.bass,
      motion.bassAttack,
      motion.bassRelease,
    );
    final mids = follow(
      value.mids,
      target.mids,
      motion.midsAttack,
      motion.midsRelease,
    );
    final treble = follow(
      value.treble,
      target.treble,
      motion.trebleAttack,
      motion.trebleRelease,
    );
    final level = follow(
      value.level,
      target.level,
      motion.levelAttack,
      motion.levelRelease,
    );
    final peak = _advancePeak(target.peak, elapsed);
    value = AudioSpectrum(
      bands: List.generate(target.bands.length, (i) {
        final position = i / math.max(1, target.bands.length - 1);
        final attack = position < 0.22
            ? motion.bassAttack
            : position < 0.68
            ? motion.midsAttack
            : motion.trebleAttack;
        final release = position < 0.22
            ? motion.bassRelease
            : position < 0.68
            ? motion.midsRelease
            : motion.trebleRelease;
        return follow(
          i < value.bands.length ? value.bands[i] : 0,
          target.bands[i],
          attack,
          release,
        );
      }),
      bass: bass,
      mids: mids,
      treble: treble,
      level: level,
      peak: peak,
      voiceActivity: follow(
        value.voiceActivity,
        target.voiceActivity,
        motion.midsAttack,
        motion.midsRelease,
      ),
    );
    return value;
  }

  double _advancePeak(double target, Duration elapsed) {
    if (target >= value.peak) {
      _peakHeld = Duration.zero;
      return target;
    }
    _peakHeld += elapsed;
    if (_peakHeld <= motion.peakHold) return value.peak;
    final fall = motion.peakFalloff * elapsed.inMicroseconds / 1000000;
    return math.max(target, value.peak - fall).clamp(0.0, 1.0);
  }
}
