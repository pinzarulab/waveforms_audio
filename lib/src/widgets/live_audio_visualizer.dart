import 'dart:async';

import 'package:flutter/material.dart';

import '../models/audio_data.dart';
import 'audio_visualizer.dart';

/// Displays a scrolling history of peak amplitudes from audio chunks.
///
/// Each nonempty chunk adds one bucket using its largest finite absolute sample,
/// clamped to 0–1. History duration therefore depends on chunk arrival cadence,
/// not the sample rate. The widget owns its stream subscription, not the source.
class LiveAudioVisualizer extends StatefulWidget {
  /// Required stream of normalized PCM samples. Empty chunks are ignored.
  /// Handle source errors upstream; this widget has no error callback.
  final Stream<List<double>> audioStream;

  /// Positive number of recent chunk peaks shown; defaults to 100.
  /// New histories start with zero-filled buckets.
  final int windowSize; // Number of visual buckets to show on screen
  /// Requested logical-pixel dimensions; defaults to full width and height 200.
  /// The parent must provide bounded width.
  final Size size;

  /// Waveform layout; defaults to [VisualizerType.linear].
  final VisualizerType type;

  /// Segment color; defaults to [Colors.redAccent].
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

  /// Positive duration of one pulse or rotation loop; defaults to two seconds.
  final Duration animationDuration;

  /// Non-negative amplitude transition duration; defaults to 100 ms.
  /// Use [Duration.zero] for immediate updates.
  final Duration transitionDuration;

  /// Creates a scrolling waveform. [key] is the standard Flutter widget key.
  ///
  /// Changing [audioStream] replaces the subscription while retaining history.
  /// Changing [windowSize] trims oldest buckets or prepends zeros.
  const LiveAudioVisualizer({
    super.key,
    required this.audioStream,
    this.windowSize = 100,
    this.size = const Size(double.infinity, 200),
    this.type = VisualizerType.linear,
    this.color = Colors.redAccent,
    this.strokeWidth = 2.0,
    this.spacing = 2.0,
    this.animatePulsate = false,
    this.animateRotation = false,
    this.animationDuration = const Duration(seconds: 2),
    this.transitionDuration = const Duration(milliseconds: 100),
  }) : assert(windowSize > 0),
       assert(strokeWidth > 0),
       assert(spacing >= 0);

  @override
  State<LiveAudioVisualizer> createState() => _LiveAudioVisualizerState();
}

class _LiveAudioVisualizerState extends State<LiveAudioVisualizer> {
  final List<double> _buffer = [];
  late StreamSubscription<List<double>> _subscription;

  @override
  void initState() {
    super.initState();
    // Initialize empty buffer
    for (int i = 0; i < widget.windowSize; i++) {
      _buffer.add(0.0);
    }

    _subscribe();
  }

  @override
  void didUpdateWidget(covariant LiveAudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.windowSize != oldWidget.windowSize) {
      if (_buffer.length > widget.windowSize) {
        _buffer.removeRange(0, _buffer.length - widget.windowSize);
      } else {
        _buffer.insertAll(
          0,
          List.filled(widget.windowSize - _buffer.length, 0.0),
        );
      }
    }
    if (widget.audioStream != oldWidget.audioStream) {
      _subscription.cancel();
      _subscribe();
    }
  }

  void _subscribe() {
    _subscription = widget.audioStream.listen((chunk) {
      // Very naive and fast processing for live data:
      // Downsample the chunk into a single point, or just take the max
      if (!mounted || chunk.isEmpty) return;

      double peak = 0.0;
      for (final sample in chunk) {
        final val = sample.abs();
        if (val.isFinite && val > peak) peak = val;
      }

      setState(() {
        _buffer.removeAt(0);
        _buffer.add(peak.clamp(0.0, 1.0));
      });
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AudioVisualizer(
      audioData: AudioData(
        samples: List<double>.of(_buffer),
        maxAmplitude: 1.0,
      ),
      size: widget.size,
      type: widget.type,
      color: widget.color,
      strokeWidth: widget.strokeWidth,
      spacing: widget.spacing,
      animatePulsate: widget.animatePulsate,
      animateRotation: widget.animateRotation,
      animationDuration: widget.animationDuration,
      transitionDuration: widget.transitionDuration,
    );
  }
}
