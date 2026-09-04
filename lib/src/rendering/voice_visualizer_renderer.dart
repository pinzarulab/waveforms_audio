/// Selects how reactive visual geometry is rendered.
enum VoiceVisualizerRenderer {
  /// Uses a fragment shader where one is available, with an automatic Canvas
  /// fallback while loading or when the platform cannot create the shader.
  auto,

  /// Always uses Flutter Canvas primitives.
  canvas,

  /// Requests the shader backend. Unsupported styles still use Canvas.
  fragmentShader,
}
