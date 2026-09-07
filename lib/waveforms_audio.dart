/// Audio visualization widgets, PCM input adapters, and styling for Flutter.
///
/// Start with [ReactiveAudioController] and [VoiceChatVisualizer] for PCM audio,
/// or [AudioVisualizer] and [AudioData] for prepared waveform snapshots.
/// Recording, playback, and compressed audio decoding belong to the host app.
library;

export 'src/models/audio_data.dart';
export 'src/utils/audio_processor.dart';
export 'src/widgets/audio_visualizer.dart';
export 'src/widgets/live_audio_visualizer.dart';
export 'src/audio/audio_decoder.dart';
export 'src/audio/audio_format.dart';
export 'src/audio/audio_motion.dart';
export 'src/audio/reactive_audio_controller.dart';
export 'src/rendering/shader_support.dart';
export 'src/rendering/voice_visualizer_renderer.dart';
export 'src/styles/voice_visualizer_style.dart';
export 'src/widgets/reactive_audio_visualizer.dart';
export 'src/widgets/voice_chat_visualizer.dart';
export 'src/audio/pcm16_decoder.dart';
export 'src/audio/pcm_resampler.dart';
