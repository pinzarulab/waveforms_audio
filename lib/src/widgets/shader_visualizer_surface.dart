import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../painters/reactive_waveform_painter.dart';
import '../painters/shader_waveform_painter.dart';
import '../shaders/visualizer_effects_shader.dart';
import '../styles/voice_visualizer_style.dart';

bool supportsFragmentShader(VoiceVisualizerKind kind) => switch (kind) {
  VoiceVisualizerKind.orb ||
  VoiceVisualizerKind.wave ||
  VoiceVisualizerKind.halo ||
  VoiceVisualizerKind.ribbon ||
  VoiceVisualizerKind.liquidOrb ||
  VoiceVisualizerKind.pulseRings ||
  VoiceVisualizerKind.voiceBloom => true,
  _ => false,
};

class ShaderVisualizerSurface extends StatefulWidget {
  final ValueNotifier<ReactiveFrame> animation;
  final VoiceVisualizerStyle style;
  final double idleBreathing;
  final bool reducedMotion;

  const ShaderVisualizerSurface({
    super.key,
    required this.animation,
    required this.style,
    required this.idleBreathing,
    required this.reducedMotion,
  });

  @override
  State<ShaderVisualizerSurface> createState() =>
      _ShaderVisualizerSurfaceState();
}

class _ShaderVisualizerSurfaceState extends State<ShaderVisualizerSurface> {
  VisualizerEffectsShaderInstance? _shader;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ui.FragmentProgram program =
          await VisualizerEffectsShaderProgram.load();
      if (!mounted) return;
      setState(() => _shader = VisualizerEffectsShaderInstance(program));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    if (shader != null &&
        !_failed &&
        widget.style.colors.length <=
            VisualizerEffectsShaderInstance.maxColorStops) {
      return CustomPaint(
        painter: ShaderWaveformPainter(
          animation: widget.animation,
          shader: shader,
          style: widget.style,
          idleBreathing: widget.idleBreathing,
          reducedMotion: widget.reducedMotion,
        ),
      );
    }
    return CustomPaint(
      painter: ReactiveWaveformPainter(
        animation: widget.animation,
        style: widget.style,
        idleBreathing: widget.idleBreathing,
        reducedMotion: widget.reducedMotion,
      ),
    );
  }
}
