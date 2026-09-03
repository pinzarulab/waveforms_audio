import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:waveforms_audio/waveforms_audio.dart';

abstract interface class MicrophoneInput {
  Future<Stream<List<double>>> start();
  Future<void> stop();
  Future<void> dispose();
}

class MicrophonePermissionDenied implements Exception {}

class RecordMicrophoneInput implements MicrophoneInput {
  AudioRecorder? _recorder;

  @override
  Future<Stream<List<double>>> start() async {
    final recorder = _recorder ??= AudioRecorder();
    if (!await recorder.hasPermission()) throw MicrophonePermissionDenied();
    final stream = await recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: MicrophoneController.sampleRate,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
      ),
    );
    final decoder = Pcm16Decoder();
    return stream.map(decoder.addBytes).where((samples) => samples.isNotEmpty);
  }

  @override
  Future<void> stop() async {
    await _recorder?.stop();
  }

  @override
  Future<void> dispose() async {
    await _recorder?.dispose();
  }
}

/// Serializes capture operations so permission/start cannot race stop/dispose.
class MicrophoneController extends ChangeNotifier {
  static const sampleRate = 48000;
  final MicrophoneInput input;
  final _audio = StreamController<List<double>>.broadcast();
  StreamSubscription<List<double>>? _subscription;
  Future<void> _operation = Future.value();
  bool _wanted = false;
  bool _disposed = false;
  bool isRecording = false;
  bool isBusy = false;
  String? error;

  MicrophoneController(this.input);
  Stream<List<double>> get stream => _audio.stream;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() {
    if (_disposed || _wanted) return _operation;
    _wanted = true;
    isBusy = true;
    error = null;
    _notify();
    return _operation = _operation.then((_) async {
      if (!_wanted || _disposed) return;
      try {
        final stream = await input.start();
        if (!_wanted || _disposed) {
          await input.stop();
          return;
        }
        isRecording = true;
        _subscription = stream.listen(
          (samples) {
            if (!_disposed && _wanted) _audio.add(samples);
          },
          onDone: () {
            if (_wanted) unawaited(stop());
          },
          onError: (Object failure) {
            error = 'Microphone disconnected. Try starting it again.';
            unawaited(stop());
          },
        );
      } catch (failure) {
        _wanted = false;
        isRecording = false;
        error = failure is MicrophonePermissionDenied
            ? 'Microphone permission denied. Allow access in system or browser settings, then try again.'
            : 'Could not start the microphone. Check your input device and try again.';
        try {
          await input.stop();
        } catch (_) {
          /* Capture may not have started. */
        }
      } finally {
        isBusy = false;
        _notify();
      }
    });
  }

  Future<void> stop() {
    _wanted = false;
    return _operation = _operation.then((_) async {
      try {
        final cancellation = _subscription?.cancel();
        _subscription = null;
        // Release the hardware before waiting for the source stream to close.
        await input.stop();
        await cancellation;
      } catch (_) {
        error =
            'Could not stop the microphone. Close the example to release it.';
      } finally {
        isRecording = false;
        isBusy = false;
        if (!_disposed) _audio.add(List.filled(2048, 0));
        _notify();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _wanted = false;
    unawaited(
      stop().then((_) async {
        try {
          await input.dispose();
        } finally {
          await _audio.close();
        }
      }),
    );
    super.dispose();
  }
}
