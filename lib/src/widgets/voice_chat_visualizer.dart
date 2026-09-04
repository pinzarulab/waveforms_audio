import 'package:flutter/material.dart';

import '../audio/audio_motion.dart';
import '../audio/reactive_audio_controller.dart';
import '../rendering/voice_visualizer_renderer.dart';
import '../styles/voice_visualizer_style.dart';
import 'reactive_audio_visualizer.dart';

/// Selected by the call's active-speaker or playback state.
enum VoiceChatSpeaker { local, remote }

extension VoiceChatSpeakerColors on VoiceChatSpeaker {
  List<Color> get colors => switch (this) {
    VoiceChatSpeaker.local => const [Color(0xFF2979FF), Color(0xFF39E9FF)],
    VoiceChatSpeaker.remote => const [Color(0xFFFF453A), Color(0xFFFFAA33)],
  };
}

/// Voice-chat visualization with smoothly animated speaker palettes.
class VoiceChatVisualizer extends StatelessWidget {
  final ReactiveAudioController? controller;
  final Stream<List<double>>? audioStream;
  final int? sampleRate;
  final VoiceChatSpeaker speaker;
  final VoiceVisualizerStyle style;
  final VoiceVisualizerRenderer renderer;
  final Size size;
  final AudioMotionPreset motionPreset;
  final AudioMotionSettings? motion;
  final List<Color>? localColors;
  final List<Color>? remoteColors;
  final Duration speakerTransition;
  final ValueChanged<double>? onVoiceActivity;
  final void Function(Object error, StackTrace stack)? onError;

  const VoiceChatVisualizer({
    super.key,
    this.controller,
    this.audioStream,
    this.sampleRate,
    required this.speaker,
    this.style = const VoiceVisualizerStyle.orb(),
    this.renderer = VoiceVisualizerRenderer.auto,
    this.size = const Size(double.infinity, 280),
    this.motionPreset = AudioMotionPreset.voice,
    this.motion,
    this.localColors,
    this.remoteColors,
    this.speakerTransition = const Duration(milliseconds: 280),
    this.onVoiceActivity,
    this.onError,
  }) : assert(
         controller != null || (audioStream != null && sampleRate != null),
         'Provide a controller, or both audioStream and sampleRate.',
       ),
       assert(
         controller == null || audioStream == null,
         'Provide either controller or audioStream, not both.',
       ),
       assert(localColors == null || localColors.length > 0),
       assert(remoteColors == null || remoteColors.length > 0);

  @override
  Widget build(BuildContext context) {
    final target = speaker == VoiceChatSpeaker.local ? 0.0 : 1.0;
    final local = localColors ?? VoiceChatSpeaker.local.colors;
    final remote = remoteColors ?? VoiceChatSpeaker.remote.colors;
    return Semantics(
      label: speaker == VoiceChatSpeaker.local
          ? 'Your voice'
          : 'Remote or AI voice',
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: target),
        duration: MediaQuery.maybeOf(context)?.disableAnimations == true
            ? Duration.zero
            : speakerTransition,
        curve: Curves.easeInOutCubic,
        builder: (context, mix, child) {
          final colors = style.colors.isEmpty
              ? [
                  Color.lerp(local.first, remote.first, mix)!,
                  Color.lerp(local.last, remote.last, mix)!,
                ]
              : style.colors;
          return ReactiveAudioVisualizer(
            controller: controller,
            audioStream: audioStream,
            sampleRate: sampleRate,
            style: style.copyWith(colors: colors),
            renderer: renderer,
            size: size,
            motionPreset: motionPreset,
            motion: motion,
            onVoiceActivity: onVoiceActivity,
            onError: onError,
          );
        },
      ),
    );
  }
}
