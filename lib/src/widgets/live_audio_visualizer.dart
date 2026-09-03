import 'dart:async';

import 'package:flutter/material.dart';

import '../models/audio_data.dart';
import 'audio_visualizer.dart';

class LiveAudioVisualizer extends StatefulWidget {
  final Stream<List<double>> audioStream;
  final int windowSize; // Number of visual buckets to show on screen
  final Size size;
  final VisualizerType type;
  final Color color;
  final double strokeWidth;
  final bool animatePulsate;
  final bool animateRotation;
  final Duration animationDuration;
  final Duration transitionDuration;

  const LiveAudioVisualizer({
    super.key,
    required this.audioStream,
    this.windowSize = 100,
    this.size = const Size(double.infinity, 200),
    this.type = VisualizerType.linear,
    this.color = Colors.redAccent,
    this.strokeWidth = 2.0,
    this.animatePulsate = false,
    this.animateRotation = false,
    this.animationDuration = const Duration(seconds: 2),
    this.transitionDuration = const Duration(milliseconds: 100),
  }) : assert(windowSize > 0);

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
      animatePulsate: widget.animatePulsate,
      animateRotation: widget.animateRotation,
      animationDuration: widget.animationDuration,
      transitionDuration: widget.transitionDuration,
    );
  }
}
