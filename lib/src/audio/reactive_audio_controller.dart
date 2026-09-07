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
/// Input defaults to [AudioFormat.sampleRate]. Each add method accepts an optional
/// `sourceSampleRate` override, retaining the encoding and channel layout in
/// [format]. Output always uses [sampleRate]. A rate switch flushes the previous
/// resampled tail and discards incomplete PCM frames.
class ReactiveAudioController {
  /// Default source PCM format. Encoding and channel layout remain fixed.
  final AudioFormat format;
  late final AudioDecoder _decoder = AudioDecoder(format);
  final StreamController<List<double>> _samples =
      StreamController<List<double>>.broadcast();

  /// Output rate used by the visualizer. Defaults to [format]'s source rate.
  final int sampleRate;
  int? _sourceSampleRate;
  PcmResampler? _resampler;

  /// Creates a PCM input sink with an optional fixed output [sampleRate].
  ///
  /// The output rate defaults to [AudioFormat.sampleRate]; nonpositive values throw
  /// [ArgumentError]. Reactive visualizers require an output rate of at least
  /// 8000 Hz. Create once per source and dispose when its owner finishes.
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

  /// Asynchronous broadcast stream of normalized mono samples at [sampleRate].
  /// Subscribe before feeding audio; events are not replayed to later listeners.
  Stream<List<double>> get stream => _samples.stream;

  /// Whether input has been closed. Add methods and [flush] then throw [StateError].
  bool get isClosed => _samples.isClosed;

  /// Decodes headerless PCM [bytes] and emits any complete resampled output.
  ///
  /// [sourceSampleRate] defaults to [AudioFormat.sampleRate] on each call. A different
  /// rate flushes the old segment and discards partial PCM frames. Nonpositive
  /// rates throw [ArgumentError]. Byte chunks may split interleaved frames.
  void addBytes(List<int> bytes, {int? sourceSampleRate}) {
    _checkOpen();
    _prepareInput(sourceSampleRate);
    final samples = _decoder.addBytes(bytes);
    _emit(samples);
  }

  /// Accepts plain base64 PCM or a `data:*;base64,...` [payload].
  ///
  /// Uses the same [sourceSampleRate] rules as [addBytes]. Invalid base64 throws
  /// [FormatException]; compressed audio must be decoded by the host first.
  void addBase64(String payload, {int? sourceSampleRate}) {
    _checkOpen();
    _prepareInput(sourceSampleRate);
    final samples = _decoder.addBase64(payload);
    _emit(samples);
  }

  /// Clamps normalized mono [samples] to -1–1 and replaces nonfinite values with zero.
  ///
  /// Uses the same [sourceSampleRate] rules as [addBytes]. These samples are
  /// already mono; [format] channel selection and byte encoding do not apply.
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

  /// Forwards [error] and an optional [stackTrace] to stream listeners.
  /// Does not close the controller or reset decoder/resampler history.
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

  /// Flushes the final resampler tail, then closes [stream].
  ///
  /// The returned future completes when the stream controller finishes closing;
  /// a paused subscriber can delay completion. The caller must stop its upstream
  /// producer first. The controller cannot be reopened.
  Future<void> close() {
    if (!isClosed) flush();
    return _samples.close();
  }

  /// Alias for [close]; releases the controller after flushing its pending tail.
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
