import 'package:flutter/material.dart';

import '../audio/audio_motion.dart';
import '../audio/reactive_audio_controller.dart';
import '../rendering/voice_visualizer_renderer.dart';
import '../styles/voice_visualizer_style.dart';
import 'reactive_audio_visualizer.dart';

/// Selected by the call's active-speaker or playback state.
enum VoiceChatSpeaker {
  /// The local user or microphone source.
  local,

  /// A remote participant or AI/playback source.
  remote,
}

/// Default palettes for the two application-selected speaker roles.
extension VoiceChatSpeakerColors on VoiceChatSpeaker {
  /// Blue–cyan for local audio; red–orange for remote or AI audio.
  List<Color> get colors => switch (this) {
    VoiceChatSpeaker.local => const [Color(0xFF2979FF), Color(0xFF39E9FF)],
    VoiceChatSpeaker.remote => const [Color(0xFFFF453A), Color(0xFFFFAA33)],
  };
}

/// Voice-chat visualization with smoothly animated speaker palettes.
class VoiceChatVisualizer extends StatelessWidget {
  /// Format-aware input, mutually exclusive with [audioStream].
  /// The caller owns and disposes this controller; the widget only subscribes.
  final ReactiveAudioController? controller;

  /// Normalized mono PCM chunks in -1–1, used with [sampleRate].
  /// Mutually exclusive with [controller]. The widget manages its subscription.
  final Stream<List<double>>? audioStream;

  /// Input samples per second for [audioStream]; at least 8000.
  /// Ignored when [controller] supplies its own output rate.
  final int? sampleRate;

  /// Required active speaker role, selected by the application’s call state.
  /// Changes animate the default palette unless [style] supplies explicit colors.
  final VoiceChatSpeaker speaker;

  /// Shape, palette, and geometry. Defaults to [VoiceVisualizerStyle.orb].
  final VoiceVisualizerStyle style;

  /// Rendering preference; defaults to [VoiceVisualizerRenderer.auto].
  /// Unsupported styles, unavailable shaders, and palettes over four stops use Canvas.
  final VoiceVisualizerRenderer renderer;

  /// Requested logical-pixel dimensions; defaults to full width and height 280.
  /// Place in a parent with bounded width.
  final Size size;

  /// Motion profile used when [motion] is null. Defaults to voice.
  final AudioMotionPreset motionPreset;

  /// Complete motion override. When provided, takes precedence over [motionPreset].
  final AudioMotionSettings? motion;

  /// Optional nonempty local palette; defaults to blue–cyan.
  /// Speaker transitions use its first and last colors only. Explicit style colors win.
  final List<Color>? localColors;

  /// Optional nonempty remote palette; defaults to red–orange.
  /// Speaker transitions use its first and last colors only. Explicit style colors win.
  final List<Color>? remoteColors;

  /// Duration of a speaker palette transition; defaults to 280 ms.
  /// Use [Duration.zero] for immediate changes. Must be non-negative.
  final Duration speakerTransition;

  /// Receives a normalized 0–1 voice-band activity estimate on audio input
  /// and zero when the visualizer settles. This is not speaker identification.
  final ValueChanged<double>? onVoiceActivity;

  /// Handles input stream errors after the visualizer starts settling.
  /// If omitted, errors are reported through [FlutterError.reportError].
  final void Function(Object error, StackTrace stack)? onError;

  /// Creates a speaker-aware reactive visualizer.
  ///
  /// Provide [controller], or [audioStream] with [sampleRate], and select [speaker].
  /// [key] is the standard Flutter widget identity key. FFT size, analysis band
  /// count, and silence timeout use [ReactiveAudioVisualizer] defaults.
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
