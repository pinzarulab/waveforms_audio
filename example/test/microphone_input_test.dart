import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/main.dart';
import 'package:example/microphone_input.dart';
import 'package:waveforms_audio/waveforms_audio.dart';

class FakeMicrophone implements MicrophoneInput {
  final audio = StreamController<List<double>>.broadcast();
  Completer<void>? pendingStart;
  bool denied = false;
  int starts = 0;
  int stops = 0;
  bool disposed = false;

  @override
  Future<Stream<List<double>>> start() async {
    starts++;
    if (pendingStart != null) await pendingStart!.future;
    if (denied) throw MicrophonePermissionDenied();
    return audio.stream;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await audio.close();
  }
}

void main() {
  test('controller reports denied permission and can retry', () async {
    final input = FakeMicrophone()..denied = true;
    final controller = MicrophoneController(input);
    await controller.start();
    expect(controller.isRecording, isFalse);
    expect(controller.isBusy, isFalse);
    expect(controller.error, contains('permission denied'));
    input.denied = false;
    await controller.start();
    expect(controller.error, isNull);
    expect(controller.isRecording, isTrue);
    final next = controller.stream.first;
    input.audio.add([0.25, -0.5]);
    expect(await next, [0.25, -0.5]);
    await controller.stop();
    expect(input.audio.hasListener, isFalse);
    controller.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(input.disposed, isTrue);
  });

  test('stop and dispose while permission is pending release capture after start resolves', () async {
    final input = FakeMicrophone()..pendingStart = Completer<void>();
    final controller = MicrophoneController(input);
    final starting = controller.start();
    await Future<void>.delayed(Duration.zero);
    final stopping = controller.stop();
    controller.dispose();
    input.pendingStart!.complete();
    await starting;
    await stopping;
    await Future<void>.delayed(Duration.zero);
    expect(controller.isRecording, isFalse);
    expect(input.audio.hasListener, isFalse);
    expect(input.stops, greaterThan(0));
    expect(input.disposed, isTrue);
  });

  testWidgets(
    'example starts microphone only on tap, previews roles, and stops in background',
    (tester) async {
      final input = FakeMicrophone();
      await tester.pumpWidget(MyApp(microphoneInput: input));
      expect(input.starts, 0);
      await tester.ensureVisible(find.text('Start microphone'));
      await tester.tap(find.text('Start microphone'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(input.starts, 1);
      expect(find.text('Stop microphone'), findsOneWidget);
      input.audio.add(List.generate(2048, (i) => i.isEven ? 0.5 : -0.5));
      await tester.pump();
      await tester.ensureVisible(find.text('Other / AI'));
      await tester.tap(find.text('Other / AI'));
      await tester.pump(const Duration(milliseconds: 300));
      final voice = tester.widget<VoiceChatVisualizer>(
        find.byType(VoiceChatVisualizer),
      );
      expect(voice.speaker, VoiceChatSpeaker.remote);
      await tester.runAsync(() async {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await Future<void>.delayed(Duration.zero);
      });
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(input.stops, greaterThan(0));
      expect(find.text('Start microphone'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(input.starts, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
      expect(input.disposed, isTrue);
    },
  );
}
