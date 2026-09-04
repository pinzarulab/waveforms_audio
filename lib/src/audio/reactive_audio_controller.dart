import 'dart:async';
import 'dart:typed_data';

import 'audio_decoder.dart';
import 'audio_format.dart';

/// A format-aware input sink for reactive visualizers.
///
/// Feed raw PCM with [addBytes], base64 PCM with [addBase64], or already
/// normalized mono samples with [addSamples]. Compressed MP3, AAC, and Opus
/// must be decoded to PCM by the host application first.
class ReactiveAudioController {
  final AudioFormat format;
  late final AudioDecoder _decoder = AudioDecoder(format);
  final StreamController<List<double>> _samples =
      StreamController<List<double>>.broadcast();

  ReactiveAudioController({required this.format});

  int get sampleRate => format.sampleRate;
  Stream<List<double>> get stream => _samples.stream;
  bool get isClosed => _samples.isClosed;

  void addBytes(List<int> bytes) {
    _checkOpen();
    final samples = _decoder.addBytes(bytes);
    if (samples.isNotEmpty) _samples.add(samples);
  }

  void addBase64(String payload) {
    _checkOpen();
    final samples = _decoder.addBase64(payload);
    if (samples.isNotEmpty) _samples.add(samples);
  }

  void addSamples(Iterable<num> samples) {
    _checkOpen();
    final normalized = Float32List.fromList(
      samples
          .map(
            (sample) => sample.toDouble().isFinite
                ? sample.toDouble().clamp(-1.0, 1.0)
                : 0.0,
          )
          .toList(growable: false),
    );
    if (normalized.isNotEmpty) _samples.add(normalized);
  }

  void addError(Object error, [StackTrace? stackTrace]) {
    _checkOpen();
    _samples.addError(error, stackTrace);
  }

  void resetDecoder() => _decoder.reset();

  Future<void> close() => _samples.close();
  Future<void> dispose() => close();

  void _checkOpen() {
    if (isClosed) throw StateError('ReactiveAudioController is closed');
  }
}
