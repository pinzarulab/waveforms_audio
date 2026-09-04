import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../audio/audio_motion.dart';
import '../audio/frequency_analyzer.dart';
import '../audio/reactive_audio_controller.dart';
import '../painters/reactive_waveform_painter.dart';
import '../rendering/voice_visualizer_renderer.dart';
import '../styles/voice_visualizer_style.dart';
import 'shader_visualizer_surface.dart';

/// Frequency-driven motion for normalized PCM or a format-aware controller.
class ReactiveAudioVisualizer extends StatefulWidget {
  final ReactiveAudioController? controller;
  final Stream<List<double>>? audioStream;
  final int? sampleRate;
  final int fftSize;
  final int bandCount;
  final Size size;
  final VoiceVisualizerStyle style;
  final VoiceVisualizerRenderer renderer;
  final AudioMotionPreset motionPreset;
  final AudioMotionSettings? motion;
  final Duration silenceDuration;
  final ValueChanged<double>? onVoiceActivity;
  final void Function(Object error, StackTrace stack)? onError;

  const ReactiveAudioVisualizer({
    super.key,
    this.controller,
    this.audioStream,
    this.sampleRate,
    this.fftSize = 2048,
    this.bandCount = 32,
    this.size = const Size(double.infinity, 280),
    this.style = const VoiceVisualizerStyle.orb(),
    this.renderer = VoiceVisualizerRenderer.auto,
    this.motionPreset = AudioMotionPreset.voice,
    this.motion,
    this.silenceDuration = const Duration(milliseconds: 260),
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
       assert(silenceDuration > Duration.zero);

  Stream<List<double>> get effectiveStream =>
      controller?.stream ?? audioStream!;
  int get effectiveSampleRate => controller?.sampleRate ?? sampleRate!;

  @override
  State<ReactiveAudioVisualizer> createState() =>
      _ReactiveAudioVisualizerState();
}

class _ReactiveAudioVisualizerState extends State<ReactiveAudioVisualizer>
    with SingleTickerProviderStateMixin {
  late FrequencyAnalyzer _analyzer;
  late SpectrumEnvelope _envelope;
  late AudioMotionSettings _motion;
  late AudioSpectrum _target;
  late final ValueNotifier<ReactiveFrame> _frame;
  late final Ticker _ticker;
  StreamSubscription<List<double>>? _subscription;
  Duration _timeSinceAudio = Duration.zero;
  Duration? _lastTick;
  double _phase = 0;
  bool _reducedMotion = false;
  int _subscriptionGeneration = 0;

  @override
  void initState() {
    super.initState();
    _resetAnalysis();
    _frame = ValueNotifier(ReactiveFrame(_target, 0));
    _ticker = createTicker(_tick);
    _subscribe();
  }

  void _resetAnalysis() {
    _motion = widget.motion ?? AudioMotionSettings.preset(widget.motionPreset);
    _analyzer = FrequencyAnalyzer(
      sampleRate: widget.effectiveSampleRate,
      fftSize: widget.fftSize,
      bandCount: widget.bandCount,
      noiseGate: _motion.noiseGate,
      adaptiveGain: _motion.adaptiveGain,
    );
    _envelope = SpectrumEnvelope(bandCount: widget.bandCount, motion: _motion);
    _target = AudioSpectrum.silence(widget.bandCount);
    _timeSinceAudio = Duration.zero;
  }

  void _subscribe() {
    final generation = ++_subscriptionGeneration;
    _subscription = widget.effectiveStream.listen(
      (chunk) {
        if (!mounted ||
            generation != _subscriptionGeneration ||
            chunk.isEmpty) {
          return;
        }
        _target = _analyzer.addSamples(chunk);
        _timeSinceAudio = Duration.zero;
        widget.onVoiceActivity?.call(_target.voiceActivity);
        _updateMotion();
      },
      onDone: () {
        if (generation == _subscriptionGeneration) _settle();
      },
      onError: (Object error, StackTrace stack) {
        if (generation != _subscriptionGeneration) return;
        _settle();
        if (widget.onError case final callback?) {
          callback(error, stack);
        } else {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'waveforms_audio',
              context: ErrorDescription(
                'while reading the reactive audio stream',
              ),
            ),
          );
        }
      },
    );
  }

  void _settle() {
    if (!mounted) return;
    _target = AudioSpectrum.silence(widget.bandCount);
    widget.onVoiceActivity?.call(0);
    _updateMotion();
  }

  void _updateMotion() {
    if (_reducedMotion) {
      _ticker.stop();
      _envelope.value = _target;
      _frame.value = ReactiveFrame(_target, 0);
    } else if (!_ticker.isActive) {
      _lastTick = null;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final delta = _lastTick == null ? Duration.zero : elapsed - _lastTick!;
    _lastTick = elapsed;
    final dt = Duration(microseconds: delta.inMicroseconds.clamp(0, 100000));
    _timeSinceAudio += dt;
    if (_timeSinceAudio >= widget.silenceDuration && _target.level != 0) {
      _target = AudioSpectrum.silence(widget.bandCount);
      widget.onVoiceActivity?.call(0);
    }
    final spectrum = _envelope.advance(_target, dt);
    _phase +=
        dt.inMicroseconds /
        1000000 *
        (0.35 + spectrum.level * 1.4 + spectrum.peak * 0.25);
    _frame.value = ReactiveFrame(spectrum, _phase);
    final silent =
        spectrum.level == 0 &&
        spectrum.peak == 0 &&
        spectrum.bands.every((value) => value == 0) &&
        _target.level == 0;
    if (silent && _motion.idleBreathing == 0) _ticker.stop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _updateMotion();
  }

  @override
  void didUpdateWidget(covariant ReactiveAudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sourceChanged =
        oldWidget.controller != widget.controller ||
        oldWidget.audioStream != widget.audioStream;
    final analysisChanged =
        sourceChanged ||
        oldWidget.effectiveSampleRate != widget.effectiveSampleRate ||
        oldWidget.fftSize != widget.fftSize ||
        oldWidget.bandCount != widget.bandCount ||
        oldWidget.motionPreset != widget.motionPreset ||
        oldWidget.motion != widget.motion;
    if (analysisChanged) {
      _resetAnalysis();
      _frame.value = ReactiveFrame(_target, _phase);
    }
    if (sourceChanged) {
      _subscriptionGeneration++;
      _subscription?.cancel();
      _subscribe();
    }
    _updateMotion();
  }

  @override
  void dispose() {
    _subscriptionGeneration++;
    _subscription?.cancel();
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final useShader =
        widget.renderer != VoiceVisualizerRenderer.canvas &&
        supportsFragmentShader(widget.style.kind);
    final surface = useShader
        ? ShaderVisualizerSurface(
            animation: _frame,
            style: widget.style,
            reducedMotion: _reducedMotion,
            idleBreathing: _motion.idleBreathing,
          )
        : CustomPaint(
            painter: ReactiveWaveformPainter(
              animation: _frame,
              style: widget.style,
              reducedMotion: _reducedMotion,
              idleBreathing: _motion.idleBreathing,
            ),
          );
    return Semantics(
      label: 'Audio-reactive ${widget.style.kind.name} visualization',
      image: true,
      child: RepaintBoundary(
        child: SizedBox.fromSize(size: widget.size, child: surface),
      ),
    );
  }
}
