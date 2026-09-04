import 'dart:convert';
import 'dart:typed_data';

import 'audio_format.dart';

/// Incrementally converts arbitrarily chunked raw PCM into normalized mono
/// samples. Partial interleaved frames are retained for the next call.
class AudioDecoder {
  final AudioFormat format;
  Uint8List _remainder = Uint8List(0);

  AudioDecoder(this.format);

  Float32List addBytes(List<int> bytes) {
    if (bytes.isEmpty && _remainder.isEmpty) return Float32List(0);
    final input = Uint8List(_remainder.length + bytes.length)
      ..setRange(0, _remainder.length, _remainder)
      ..setRange(_remainder.length, _remainder.length + bytes.length, bytes);
    final completeLength = input.length - input.length % format.bytesPerFrame;
    _remainder = Uint8List.fromList(input.sublist(completeLength));
    if (completeLength == 0) return Float32List(0);

    final frameCount = completeLength ~/ format.bytesPerFrame;
    final output = Float32List(frameCount);
    final data = ByteData.sublistView(input, 0, completeLength);
    for (var frame = 0; frame < frameCount; frame++) {
      final frameOffset = frame * format.bytesPerFrame;
      if (format.channel case final selected?) {
        output[frame] = _sample(
          data,
          frameOffset + selected * format.bytesPerSample,
        );
      } else {
        var mixed = 0.0;
        for (var channel = 0; channel < format.channels; channel++) {
          mixed += _sample(data, frameOffset + channel * format.bytesPerSample);
        }
        output[frame] = (mixed / format.channels).clamp(-1.0, 1.0);
      }
    }
    return output;
  }

  /// Accepts plain base64 or a `data:*;base64,...` payload.
  Float32List addBase64(String payload) {
    final separator = payload.indexOf(',');
    final encoded = payload.startsWith('data:') && separator >= 0
        ? payload.substring(separator + 1)
        : payload;
    return addBytes(base64Decode(encoded));
  }

  void reset() => _remainder = Uint8List(0);

  double _sample(ByteData data, int offset) {
    final value = switch (format.encoding) {
      AudioEncoding.pcm16 => data.getInt16(offset, format.endian) / 32768.0,
      AudioEncoding.pcm24 => _pcm24(data, offset) / 8388608.0,
      AudioEncoding.float32 => data.getFloat32(offset, format.endian),
    };
    return value.isFinite ? value.clamp(-1.0, 1.0) : 0.0;
  }

  int _pcm24(ByteData data, int offset) {
    final value = format.endian == Endian.little
        ? data.getUint8(offset) |
              data.getUint8(offset + 1) << 8 |
              data.getUint8(offset + 2) << 16
        : data.getUint8(offset) << 16 |
              data.getUint8(offset + 1) << 8 |
              data.getUint8(offset + 2);
    return value & 0x800000 == 0 ? value : value - 0x1000000;
  }
}
