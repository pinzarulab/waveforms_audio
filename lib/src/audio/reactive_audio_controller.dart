import 'dart:async';
import 'dart:typed_data';

import 'audio_decoder.dart';
import 'audio_format.dart';
import 'pcm_resampler.dart';

/// A format-aware input sink for reactive visualizers.
///
/// Feed raw PCM with [addBytes], base64 PCM with [addBase64], or already
/// normalized mono samples with [addSamples]. Compressed MP3, AAC, and Opus
/// must be decoded to PCM by the host application first.
///
/// Input defaults to [format.sampleRate]. Each add method accepts an optional
/// `sourceSampleRate` override, retaining the encoding and channel layout in
/// [format]. Output always uses [sampleRate]. A rate switch flushes the previous
/// resampled tail and discards incomplete PCM frames.
class ReactiveAudioController {
  final AudioFormat format;
  late final AudioDecoder _decoder = AudioDecoder(format);
  final StreamController<List<double>> _samples =
      StreamController<List<double>>.broadcast();

  /// Output rate used by the visualizer. Defaults to [format]'s source rate.
  final int sampleRate;
  int? _sourceSampleRate;
  PcmResampler? _resampler;

  ReactiveAudioController({required this.format, int? sampleRate})
    : sampleRate = sampleRate ?? format.sampleRate {
    if (this.sampleRate <= 0) {
      throw ArgumentError.value(
        this.sampleRate,
        'sampleRate',
        'Must be positive',
      );
    }
  }

  Stream<List<double>> get stream => _samples.stream;
  bool get isClosed => _samples.isClosed;

  void addBytes(List<int> bytes, {int? sourceSampleRate}) {
    _checkOpen();
    _prepareInput(sourceSampleRate);
    final samples = _decoder.addBytes(bytes);
    _emit(samples);
  }

  void addBase64(String payload, {int? sourceSampleRate}) {
    _checkOpen();
    _prepareInput(sourceSampleRate);
    final samples = _decoder.addBase64(payload);
    _emit(samples);
  }

  void addSamples(Iterable<num> samples, {int? sourceSampleRate}) {
    _checkOpen();
    _prepareInput(sourceSampleRate);
    final normalized = Float32List.fromList(
      samples
          .map(
            (sample) => sample.toDouble().isFinite
                ? sample.toDouble().clamp(-1.0, 1.0)
                : 0.0,
          )
          .toList(growable: false),
    );
    _emit(normalized);
  }

  void addError(Object error, [StackTrace? stackTrace]) {
    _checkOpen();
    _samples.addError(error, stackTrace);
  }

  /// Discards partial PCM frames and resampling history.
  void resetDecoder() {
    _decoder.reset();
    _resampler?.reset();
  }

  /// Emits the final resampled tail and discards incomplete PCM frames.
  void flush() {
    _checkOpen();
    final tail = _resampler?.flush();
    if (tail != null && tail.isNotEmpty) _samples.add(tail);
    _decoder.reset();
  }

  Future<void> close() {
    if (!isClosed) flush();
    return _samples.close();
  }

  Future<void> dispose() => close();

  void _prepareInput(int? sourceSampleRate) {
    final rate = sourceSampleRate ?? format.sampleRate;
    if (rate <= 0) {
      throw ArgumentError.value(rate, 'sourceSampleRate', 'Must be positive');
    }
    if (rate == _sourceSampleRate) return;
    // A new rate starts an independent input segment: never join partial frames
    // or interpolate between samples recorded at different rates.
    flush();
    _sourceSampleRate = rate;
    _resampler = rate == sampleRate
        ? null
        : PcmResampler(sourceSampleRate: rate, targetSampleRate: sampleRate);
  }

  void _emit(Float32List samples) {
    final output = _resampler?.addSamples(samples) ?? samples;
    if (output.isNotEmpty) _samples.add(output);
  }

  void _checkOpen() {
    if (isClosed) throw StateError('ReactiveAudioController is closed');
  }
}
