import '../shaders/visualizer_effects_shader.dart';

/// Loads and caches the package's fragment programs before an animation starts.
///
/// This is optional. Visualizers load shaders lazily and display their Canvas
/// fallback until loading completes.
///
/// Call after Flutter bindings are initialized. The future completes after
/// loading or propagates the loading error; catch it if prewarming is optional.
/// Normal widget rendering catches loading failures and uses Canvas.
Future<void> precacheWaveformsAudioShaders() async {
  await VisualizerEffectsShaderProgram.load();
}
