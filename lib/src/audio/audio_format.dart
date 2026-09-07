import 'dart:typed_data';

/// Uncompressed PCM encodings understood by [AudioFormat].
enum AudioEncoding {
  /// Signed 16-bit integer PCM, two bytes per channel sample.
  pcm16,

  /// Signed 24-bit integer PCM, three bytes per channel sample.
  pcm24,

  /// IEEE 754 Float32 PCM, four bytes per channel sample.
  float32,
}

/// Describes raw, interleaved PCM received from a microphone, file decoder,
/// network API, or speech service.
class AudioFormat {
  /// Required PCM sample representation; compressed formats are not supported.
  final AudioEncoding encoding;

  /// Required source sample rate in Hz; at least 8000.
  final int sampleRate;

  /// Number of interleaved input channels; positive, defaults to 1.
  final int channels;

  /// Byte order of multibyte samples; defaults to [Endian.little].
  final Endian endian;

  /// Zero-based channel to visualize. Null averages every channel to mono.
  final int? channel;

  /// Describes headerless PCM. [channel] must be null or in 0..[channels] - 1.
  ///
  /// For stereo, use [channels] = 2. Leave [channel] null to average both channels
  /// or select a zero-based channel. Strip container headers before decoding.
  const AudioFormat({
    required this.encoding,
    required this.sampleRate,
    this.channels = 1,
    this.endian = Endian.little,
    this.channel,
  }) : assert(sampleRate >= 8000),
       assert(channels > 0),
       assert(channel == null || (channel >= 0 && channel < channels));

  /// Bytes per channel sample: 2 for PCM16, 3 for PCM24, 4 for Float32.
  int get bytesPerSample => switch (encoding) {
    AudioEncoding.pcm16 => 2,
    AudioEncoding.pcm24 => 3,
    AudioEncoding.float32 => 4,
  };

  /// Bytes for one complete interleaved frame across every channel.
  int get bytesPerFrame => bytesPerSample * channels;
}
