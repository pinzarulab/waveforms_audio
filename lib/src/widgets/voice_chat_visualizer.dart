import 'package:flutter/material.dart';

import '../painters/reactive_waveform_painter.dart';
import 'reactive_audio_visualizer.dart';

/// Set by the chat's active-speaker or playback state, not inferred from pitch.
enum VoiceChatSpeaker { local, remote }

extension VoiceChatSpeakerColors on VoiceChatSpeaker {
  Color get color => switch (this) {
    VoiceChatSpeaker.local => const Color(0xFF2979FF),
    VoiceChatSpeaker.remote => const Color(0xFFFF453A),
  };

  Color get secondaryColor => switch (this) {
    VoiceChatSpeaker.local => const Color(0xFF39E9FF),
    VoiceChatSpeaker.remote => const Color(0xFFFFAA33),
  };
}

/// Role colors with a smooth transition for an active voice-chat audio feed.
///
/// Feed local microphone PCM for [VoiceChatSpeaker.local], and decoded remote
/// or AI playback PCM for [VoiceChatSpeaker.remote]. The app owns speaker
/// selection, playback timing, and audio capture. When switching between source
/// streams, provide broadcast streams so they can be subscribed to again.
class VoiceChatVisualizer extends StatelessWidget {
  final Stream<List<double>> audioStream;
  final int sampleRate;
  final VoiceChatSpeaker speaker;
  final ReactiveVisualizerStyle style;
  final Size size;
  final Duration attack;
  final Duration release;

  const VoiceChatVisualizer({
    super.key,
    required this.audioStream,
    required this.sampleRate,
    required this.speaker,
    this.style = ReactiveVisualizerStyle.orb,
    this.size = const Size(double.infinity, 280),
    this.attack = const Duration(milliseconds: 45),
    this.release = const Duration(milliseconds: 320),
  });

  @override
  Widget build(BuildContext context) {
    final target = speaker == VoiceChatSpeaker.local ? 0.0 : 1.0;
    return Semantics(
      label: speaker == VoiceChatSpeaker.local
          ? 'Your voice'
          : 'Remote or AI voice',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: target, end: target),
        duration: MediaQuery.maybeOf(context)?.disableAnimations == true
            ? Duration.zero
            : const Duration(milliseconds: 240),
        curve: Curves.easeInOutCubic,
        builder: (context, mix, child) => ReactiveAudioVisualizer(
          audioStream: audioStream,
          sampleRate: sampleRate,
          style: style,
          size: size,
          attack: attack,
          release: release,
          color: Color.lerp(
            VoiceChatSpeaker.local.color,
            VoiceChatSpeaker.remote.color,
            mix,
          )!,
          secondaryColor: Color.lerp(
            VoiceChatSpeaker.local.secondaryColor,
            VoiceChatSpeaker.remote.secondaryColor,
            mix,
          )!,
        ),
      ),
    );
  }
}
