import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/audio_data.dart';
import '../painters/visualizer_painter.dart';
import '../painters/linear_waveform_painter.dart';
import '../painters/circular_waveform_painter.dart';
import '../painters/oval_waveform_painter.dart';

/// Layouts supported by classic waveform widgets.
enum VisualizerType {
  /// Vertical segments arranged horizontally.
  linear,

  /// Segments arranged around a circle.
  circular,

  /// Segments arranged around an ellipse.
  oval,
}

/// Draws a snapshot of waveform amplitudes, with optional transitions and loops.
///
/// Use [AudioData] directly or obtain a snapshot with `AudioProcessor.extractPeaks`.
/// This widget does not subscribe to audio, record, or play sound.
class AudioVisualizer extends StatefulWidget {
  /// Required immutable waveform snapshot; one sample per visual segment.
  final AudioData audioData;

  /// Requested logical-pixel dimensions; defaults to full width and height 200.
  /// The parent must provide bounded width.
  final Size size;

  /// Waveform layout; defaults to [VisualizerType.linear].
  final VisualizerType type;

  /// Segment color; defaults to [Colors.blue].
  final Color color;

  /// Positive segment thickness in logical pixels; defaults to 2.
  final double strokeWidth;

  /// Non-negative gap between linear bars in logical pixels; defaults to 2.
  /// Circular and oval layouts do not use this value.
  final double spacing;

  /// Whether to loop a gentle amplitude pulse; defaults to false.
  final bool animatePulsate;

  /// Whether to rotate circular or oval layouts; defaults to false.
  /// Ignored for linear layouts and when the system requests reduced motion.
  final bool animateRotation;

  /// Duration of one complete pulse or rotation loop.
  final Duration animationDuration;

  /// Eases amplitude changes from the currently displayed waveform.
  /// Set to [Duration.zero] for immediate updates.
  final Duration transitionDuration;

  /// Creates a classic waveform view.
  ///
  /// [key] is the standard Flutter widget identity key. [animationDuration] must
  /// be positive and [transitionDuration] non-negative. Reduced motion disables
  /// loops and displays new snapshots immediately.
  const AudioVisualizer({
    super.key,
    required this.audioData,
    this.size = const Size(double.infinity, 200),
    this.type = VisualizerType.linear,
    this.color = Colors.blue,
    this.strokeWidth = 2.0,
    this.spacing = 2.0,
    this.animatePulsate = false,
    this.animateRotation = false,
    this.animationDuration = const Duration(seconds: 2),
    this.transitionDuration = const Duration(milliseconds: 100),
  }) : assert(strokeWidth > 0),
       assert(spacing >= 0);

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _transition;
  late final Listenable _animations;
  late AudioData _fromData;
  late AudioData _targetData;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _transition = AnimationController(
      vsync: this,
      duration: widget.transitionDuration,
      value: 1,
    );
    _animations = Listenable.merge([_controller, _transition]);
    _fromData = _targetData = _snapshot(widget.audioData);
  }

  AudioData _snapshot(AudioData data) => AudioData(
    samples: List<double>.of(data.samples),
    maxAmplitude: data.maxAmplitude,
  );

  AudioData get _displayedData {
    if (_transition.isCompleted) return _targetData;
    final t = Curves.easeOutCubic.transform(_transition.value);
    return AudioData(
      samples: List<double>.generate(_targetData.samples.length, (i) {
        final from = _fromData.samples[i];
        return from + (_targetData.samples[i] - from) * t;
      }),
      maxAmplitude: _targetData.maxAmplitude,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reduceMotion) _transition.value = 1;
    _syncLoop();
  }

  void _syncLoop({bool durationChanged = false}) {
    assert(widget.animationDuration > Duration.zero);
    assert(widget.transitionDuration >= Duration.zero);
    final shouldAnimate =
        !_reduceMotion &&
        (widget.animatePulsate ||
            (widget.animateRotation && widget.type != VisualizerType.linear));
    if (!shouldAnimate) {
      _controller.stop();
    } else if (!_controller.isAnimating || durationChanged) {
      // A continuous phase gives pulse and rotation a seamless shared loop.
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final durationChanged =
        widget.animationDuration != oldWidget.animationDuration;
    _controller.duration = widget.animationDuration;
    _transition.duration = widget.transitionDuration;
    _syncLoop(durationChanged: durationChanged);

    if (!listEquals(widget.audioData.samples, _targetData.samples) ||
        widget.audioData.maxAmplitude != _targetData.maxAmplitude) {
      _fromData = _displayedData;
      _targetData = _snapshot(widget.audioData);
      if (_reduceMotion ||
          widget.transitionDuration == Duration.zero ||
          _fromData.samples.length != _targetData.samples.length) {
        _transition.value = 1;
      } else {
        _transition.forward(from: 0);
      }
    } else if (widget.transitionDuration == Duration.zero) {
      _transition.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _transition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size.width,
        height: widget.size.height,
        child: AnimatedBuilder(
          animation: _animations,
          builder: (context, child) {
            final VisualizerPainter painter;
            final data = _displayedData;
            final pulsate = widget.animatePulsate && !_reduceMotion;
            final rotate = widget.animateRotation && !_reduceMotion;
            switch (widget.type) {
              case VisualizerType.linear:
                painter = LinearWaveformPainter(
                  audioData: data,
                  color: widget.color,
                  strokeWidth: widget.strokeWidth,
                  spacing: widget.spacing,
                  animatePulsate: pulsate,
                  animationValue: _controller.value,
                );
              case VisualizerType.circular:
                painter = CircularWaveformPainter(
                  audioData: data,
                  color: widget.color,
                  strokeWidth: widget.strokeWidth,
                  animatePulsate: pulsate,
                  animateRotation: rotate,
                  animationValue: _controller.value,
                );
              case VisualizerType.oval:
                painter = OvalWaveformPainter(
                  audioData: data,
                  color: widget.color,
                  strokeWidth: widget.strokeWidth,
                  animatePulsate: pulsate,
                  animateRotation: rotate,
                  animationValue: _controller.value,
                );
            }
            return CustomPaint(painter: painter, size: widget.size);
          },
        ),
      ),
    );
  }
}
