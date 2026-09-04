import 'dart:typed_data';

/// Uncompressed PCM encodings understood by [AudioFormat].
enum AudioEncoding { pcm16, pcm24, float32 }

/// Describes raw, interleaved PCM received from a microphone, file decoder,
/// network API, or speech service.
class AudioFormat {
  final AudioEncoding encoding;
  final int sampleRate;
  final int channels;
  final Endian endian;

  /// Zero-based channel to visualize. Null averages every channel to mono.
  final int? channel;

  const AudioFormat({
    required this.encoding,
    required this.sampleRate,
    this.channels = 1,
    this.endian = Endian.little,
    this.channel,
  }) : assert(sampleRate >= 8000),
       assert(channels > 0),
       assert(channel == null || (channel >= 0 && channel < channels));

  int get bytesPerSample => switch (encoding) {
    AudioEncoding.pcm16 => 2,
    AudioEncoding.pcm24 => 3,
    AudioEncoding.float32 => 4,
  };

  int get bytesPerFrame => bytesPerSample * channels;
}
