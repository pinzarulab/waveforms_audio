import '../shaders/visualizer_effects_shader.dart';

/// Loads and caches the package's fragment programs before an animation starts.
///
/// This is optional. Visualizers load shaders lazily and display their Canvas
/// fallback until loading completes.
Future<void> precacheWaveformsAudioShaders() async {
  await VisualizerEffectsShaderProgram.load();
}
