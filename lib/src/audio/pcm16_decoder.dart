import 'dart:typed_data';

/// Decodes mono signed 16-bit little-endian PCM into normalized -1–1 samples.
/// Retains a trailing byte across chunks. Create one decoder per audio source;
/// do not pass WAV headers, compressed audio, or interleaved stereo data.
class Pcm16Decoder {
  int? _pendingByte;

  List<double> addBytes(Uint8List bytes) {
    final samples = <double>[];
    var index = 0;
    if (_pendingByte != null && bytes.isNotEmpty) {
      samples.add(_decode(_pendingByte!, bytes[index++]));
      _pendingByte = null;
    }
    while (index + 1 < bytes.length) {
      samples.add(_decode(bytes[index], bytes[index + 1]));
      index += 2;
    }
    if (index < bytes.length) _pendingByte = bytes[index];
    return samples;
  }

  double _decode(int low, int high) {
    final unsigned = low | (high << 8);
    return (unsigned >= 0x8000 ? unsigned - 0x10000 : unsigned) / 32768.0;
  }
}
