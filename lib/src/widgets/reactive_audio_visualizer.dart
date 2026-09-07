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
  /// Format-aware input, mutually exclusive with [audioStream].
  /// The caller owns and disposes this controller; the widget only subscribes.
  final ReactiveAudioController? controller;

  /// Normalized mono PCM chunks in -1–1, used with [sampleRate].
  /// Mutually exclusive with [controller]. The widget manages its subscription.
  final Stream<List<double>>? audioStream;

  /// Input samples per second for [audioStream]; at least 8000.
  /// Ignored when [controller] supplies its own output rate.
  final int? sampleRate;

  /// Rolling FFT window in samples. Defaults to 2048; power of two, 256–8192.
  /// Larger windows improve frequency resolution at increased computation cost.
  final int fftSize;

  /// Number of logarithmic analysis bands, 3–128; defaults to 32.
  /// Independent of the style’s number of visible bars.
  final int bandCount;

  /// Requested logical-pixel dimensions; defaults to full width and height 280.
  /// Place in a parent with bounded width.
  final Size size;

  /// Shape, palette, and geometry. Defaults to [VoiceVisualizerStyle.orb].
  final VoiceVisualizerStyle style;

  /// Rendering preference; defaults to [VoiceVisualizerRenderer.auto].
  /// Unsupported styles, unavailable shaders, and palettes over four stops use Canvas.
  final VoiceVisualizerRenderer renderer;

  /// Motion profile used when [motion] is null. Defaults to voice.
  final AudioMotionPreset motionPreset;

  /// Complete motion override. When provided, takes precedence over [motionPreset].
  final AudioMotionSettings? motion;

  /// Gap without audio before a nonzero level starts settling; defaults to 260 ms.
  /// Must be positive. Continuous idle breathing is controlled by [motion].
  final Duration silenceDuration;

  /// Receives a normalized 0–1 voice-band activity estimate on audio input
  /// and zero when the visualizer settles. This is not speaker identification.
  final ValueChanged<double>? onVoiceActivity;

  /// Handles input stream errors after the visualizer starts settling.
  /// If omitted, errors are reported through [FlutterError.reportError].
  final void Function(Object error, StackTrace stack)? onError;

  /// Creates a reactive view from [controller], or [audioStream] and [sampleRate].
  ///
  /// [key] is the standard Flutter widget identity key. System reduced-motion
  /// settings disable continuous animation while preserving incoming audio state.
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

  /// The controller stream when present, otherwise [audioStream].
  Stream<List<double>> get effectiveStream =>
      controller?.stream ?? audioStream!;

  /// The controller output rate when present, otherwise [sampleRate].
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
