import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../audio/frequency_analyzer.dart';
import '../painters/reactive_waveform_painter.dart';

/// Frequency-driven motion for voice, music, or any mono PCM stream.
///
/// Supply normalized PCM (-1–1), not peak values or encoded audio bytes.
/// [sampleRate] must match the source. Use [style] to choose an orb, wave,
/// centered/upward spectrum bars, five voice bars, or a segmented halo.
class ReactiveAudioVisualizer extends StatefulWidget {
  final Stream<List<double>> audioStream;
  final int sampleRate;
  final int fftSize;
  final int bandCount;
  final Size size;
  final ReactiveVisualizerStyle style;
  final Color color;
  final Color secondaryColor;

  /// Optional resting color, blended into the active gradient as audio rises.
  /// Null keeps the active palette even in silence.
  final Color? inactiveColor;
  final Duration attack;
  final Duration release;

  const ReactiveAudioVisualizer({
    super.key,
    required this.audioStream,
    required this.sampleRate,
    this.fftSize = 2048,
    this.bandCount = 32,
    this.size = const Size(double.infinity, 280),
    this.style = ReactiveVisualizerStyle.orb,
    this.color = const Color(0xFF72F5D1),
    this.secondaryColor = const Color(0xFF6B8CFF),
    this.inactiveColor,
    this.attack = const Duration(milliseconds: 45),
    this.release = const Duration(milliseconds: 320),
  });

  @override
  State<ReactiveAudioVisualizer> createState() =>
      _ReactiveAudioVisualizerState();
}

class _ReactiveAudioVisualizerState extends State<ReactiveAudioVisualizer>
    with SingleTickerProviderStateMixin {
  late FrequencyAnalyzer _analyzer;
  late SpectrumEnvelope _envelope;
  late AudioSpectrum _target;
  late final ValueNotifier<ReactiveFrame> _frame;
  late final Ticker _ticker;
  StreamSubscription<List<double>>? _subscription;
  Timer? _silenceTimer;
  Duration? _lastTick;
  double _phase = 0;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _resetAnalysis();
    _frame = ValueNotifier(ReactiveFrame(_target, 0));
    _ticker = createTicker(_tick);
    _subscribe();
  }

  void _resetAnalysis() {
    _analyzer = FrequencyAnalyzer(
      sampleRate: widget.sampleRate,
      fftSize: widget.fftSize,
      bandCount: widget.bandCount,
    );
    _envelope = SpectrumEnvelope(
      bandCount: widget.bandCount,
      attack: widget.attack,
      release: widget.release,
    );
    _target = AudioSpectrum.silence(widget.bandCount);
  }

  void _subscribe() {
    _subscription = widget.audioStream.listen(
      (chunk) {
        if (!mounted || chunk.isEmpty) return;
        _target = _analyzer.addSamples(chunk);
        _silenceTimer?.cancel();
        // Also settle when a microphone pauses without sending zero samples.
        final timeoutMs = math.max(
          220,
          chunk.length * 1500 ~/ widget.sampleRate,
        );
        _silenceTimer = Timer(Duration(milliseconds: timeoutMs), _settle);
        _updateMotion();
      },
      onDone: _settle,
      onError: (Object error, StackTrace stack) {
        _settle();
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
      },
    );
  }

  void _settle() {
    if (!mounted) return;
    _target = AudioSpectrum.silence(widget.bandCount);
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
    final spectrum = _envelope.advance(_target, dt);
    _phase += dt.inMicroseconds / 1e6 * (0.35 + spectrum.level * 1.4);
    _frame.value = ReactiveFrame(spectrum, _phase);
    if (spectrum.level == 0 &&
        spectrum.bands.every((value) => value == 0) &&
        _target.level == 0 &&
        _target.bands.every((value) => value == 0)) {
      _ticker.stop();
    }
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
    final streamChanged = oldWidget.audioStream != widget.audioStream;
    if (streamChanged ||
        oldWidget.sampleRate != widget.sampleRate ||
        oldWidget.fftSize != widget.fftSize ||
        oldWidget.bandCount != widget.bandCount ||
        oldWidget.attack != widget.attack ||
        oldWidget.release != widget.release) {
      _silenceTimer?.cancel();
      _resetAnalysis();
      _frame.value = ReactiveFrame(_target, _phase);
    }
    if (streamChanged) {
      _subscription?.cancel();
      _subscribe();
    }
    _updateMotion();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _silenceTimer?.cancel();
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Audio-reactive ${widget.style.name} visualization',
    image: true,
    child: RepaintBoundary(
      child: SizedBox.fromSize(
        size: widget.size,
        child: CustomPaint(
          painter: ReactiveWaveformPainter(
            animation: _frame,
            style: widget.style,
            color: widget.color,
            secondaryColor: widget.secondaryColor,
            inactiveColor: widget.inactiveColor,
            reducedMotion: _reducedMotion,
          ),
        ),
      ),
    ),
  );
}
