import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:waveforms_audio/waveforms_audio.dart';

import 'microphone_input.dart';

void main() => runApp(const MyApp());

const _mint = Color(0xFF9AF2D2);
const _muted = Color(0xFF889B98);
const _background = Color(0xFF0B1212);

enum DemoSignal { bass, voice, air }

class MyApp extends StatelessWidget {
  final MicrophoneInput? microphoneInput;
  const MyApp({super.key, this.microphoneInput});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Waveforms · Motion Lab',
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _mint,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      fontFamily: 'sans-serif',
    ),
    home: VisualizerShowcase(microphoneInput: microphoneInput),
  );
}

class VisualizerShowcase extends StatefulWidget {
  final MicrophoneInput? microphoneInput;
  const VisualizerShowcase({super.key, this.microphoneInput});

  @override
  State<VisualizerShowcase> createState() => _VisualizerShowcaseState();
}

class _VisualizerShowcaseState extends State<VisualizerShowcase>
    with WidgetsBindingObserver {
  final _stream = StreamController<List<double>>.broadcast();
  late final Timer _timer;
  late final MicrophoneController _microphone;
  bool _useMicrophone = true;
  VoiceChatSpeaker _speaker = VoiceChatSpeaker.local;
  ReactiveVisualizerStyle _style = ReactiveVisualizerStyle.orb;
  DemoSignal _signal = DemoSignal.voice;
  bool _playing = true;
  int _sampleCursor = 0;
  static const _sampleRate = 48000;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _microphone = MicrophoneController(
      widget.microphoneInput ?? RecordMicrophoneInput(),
    );
    _microphone.addListener(_onMicrophoneChanged);
    // Continuous, signed PCM at the declared sample rate. No microphone required.
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_playing || _useMicrophone) return;
      final samples = List<double>.generate(768, (_) {
        final time = _sampleCursor++ / _sampleRate;
        switch (_signal) {
          case DemoSignal.bass:
            final beat = time % 0.8;
            final envelope = (1 - math.exp(-beat * 90)) * math.exp(-beat * 6);
            return math.sin(2 * math.pi * 90 * time) * envelope * 0.8;
          case DemoSignal.voice:
            final phrase = math.pow(0.5 + 0.5 * math.sin(time * 2.1), 2);
            final syllable = 0.35 + 0.65 * math.pow(math.sin(time * 7.2), 2);
            final fundamental = math.sin(2 * math.pi * 180 * time);
            final formants =
                math.sin(2 * math.pi * 720 * time) * 0.42 +
                math.sin(2 * math.pi * 1440 * time) * 0.2;
            return (fundamental * 0.35 + formants) * phrase * syllable * 0.65;
          case DemoSignal.air:
            final shimmer =
                0.15 + 0.85 * math.pow(0.5 + 0.5 * math.sin(time * 5), 2);
            return (math.sin(2 * math.pi * 3600 * time) * 0.35 +
                    math.sin(2 * math.pi * 7200 * time) * 0.18) *
                shimmer;
        }
      });
      _stream.add(samples);
    });
  }

  void _onMicrophoneChanged() {
    if (mounted) setState(() {});
  }

  void _selectInput(bool microphone) {
    if (_microphone.isBusy) return;
    if (!microphone) unawaited(_microphone.stop());
    setState(() => _useMicrophone = microphone);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_microphone.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _microphone.removeListener(_onMicrophoneChanged);
    _microphone.dispose();
    _timer.cancel();
    _stream.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.graphic_eq_rounded,
                      color: _mint,
                      size: 25,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'WAVEFORMS',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'MOTION LAB / 01',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: _muted.withValues(alpha: 0.9),
                          letterSpacing: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 38),
                const Text(
                  'Sound, with a pulse.',
                  style: TextStyle(
                    fontSize: 34,
                    height: 1.12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -1.3,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Quick to respond. Gentle to settle.',
                  style: TextStyle(color: _muted, fontSize: 15),
                ),
                const SizedBox(height: 28),
                Row(
                  children: ReactiveVisualizerStyle.values
                      .map(
                        (style) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: _Choice(
                              label: switch (style) {
                                ReactiveVisualizerStyle.orb => 'Orb',
                                ReactiveVisualizerStyle.wave => 'Wave',
                                ReactiveVisualizerStyle.bars => 'Spectrum',
                              },
                              icon: switch (style) {
                                ReactiveVisualizerStyle.orb =>
                                  Icons.blur_circular_rounded,
                                ReactiveVisualizerStyle.wave =>
                                  Icons.waves_rounded,
                                ReactiveVisualizerStyle.bars =>
                                  Icons.equalizer_rounded,
                              },
                              selected: _style == style,
                              onTap: () => setState(() => _style = style),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _Choice(
                        label: 'Microphone',
                        icon: Icons.mic_none_rounded,
                        selected: _useMicrophone,
                        onTap: () => _selectInput(true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Choice(
                        label: 'Demo signal',
                        icon: Icons.science_outlined,
                        selected: !_useMicrophone,
                        onTap: () => _selectInput(false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _Choice(
                        label: 'You',
                        subtitle: 'Blue → cyan',
                        selected: _speaker == VoiceChatSpeaker.local,
                        onTap: () =>
                            setState(() => _speaker = VoiceChatSpeaker.local),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Choice(
                        label: 'Other / AI',
                        subtitle: 'Red → orange',
                        selected: _speaker == VoiceChatSpeaker.remote,
                        onTap: () =>
                            setState(() => _speaker = VoiceChatSpeaker.remote),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (_useMicrophone) ...[
                  FilledButton.icon(
                    onPressed: _microphone.isBusy
                        ? null
                        : () {
                            if (_microphone.isRecording) {
                              unawaited(_microphone.stop());
                            } else {
                              unawaited(_microphone.start());
                            }
                          },
                    icon: Icon(
                      _microphone.isRecording
                          ? Icons.stop_rounded
                          : Icons.mic_rounded,
                    ),
                    label: Text(
                      _microphone.isBusy
                          ? 'Starting microphone…'
                          : _microphone.isRecording
                          ? 'Stop microphone'
                          : 'Start microphone',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _microphone.isRecording
                        ? 'Speak now. Your voice drives the animation.'
                        : 'Use your real voice. Nothing is saved or uploaded.',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                  if (_microphone.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _microphone.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                ],
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFF253331)),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF162422),
                        Color(0xFF10191B),
                        Color(0xFF111923),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color:
                                    (_useMicrophone
                                        ? _microphone.isRecording
                                        : _playing)
                                    ? _speaker.secondaryColor
                                    : _muted,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _useMicrophone
                                    ? (_microphone.isRecording
                                          ? 'LIVE MICROPHONE'
                                          : 'MICROPHONE OFF')
                                    : (_playing
                                          ? 'DEMO SIGNAL'
                                          : 'SETTLING INTO SILENCE'),
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 9,
                                  letterSpacing: 1.4,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '48 kHz',
                              style: TextStyle(color: _muted, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) => VoiceChatVisualizer(
                          audioStream: _useMicrophone
                              ? _microphone.stream
                              : _stream.stream,
                          sampleRate: _sampleRate,
                          speaker: _speaker,
                          style: _style,
                          size: Size(
                            double.infinity,
                            math.min(340, constraints.maxWidth * 0.92),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                        child: Column(
                          children: [
                            Text(
                              switch (_style) {
                                ReactiveVisualizerStyle.orb =>
                                  'A little more alive.',
                                ReactiveVisualizerStyle.wave =>
                                  'Let the sound flow.',
                                ReactiveVisualizerStyle.bars =>
                                  'Every frequency, its own rhythm.',
                              },
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 17,
                                color: Color(0xFFDBE9E4),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              switch (_style) {
                                ReactiveVisualizerStyle.orb =>
                                  'Bass expands · voice shapes · highs ripple',
                                ReactiveVisualizerStyle.wave => 'Layered waves follow the energy of your sound',
                                ReactiveVisualizerStyle.bars => 'Low frequencies on the left, highs on the right',
                              },
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _useMicrophone
                      ? 'Speaker color preview: both roles use your microphone here. In a chat, connect each participant’s own audio.'
                      : 'Speaker color preview with a synthetic signal.',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
                if (!_useMicrophone) ...[
                  const SizedBox(height: 28),
                  const Text(
                    'FEEL THE DIFFERENCE',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.7,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: DemoSignal.values
                        .map(
                          (signal) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: _Choice(
                                label: switch (signal) {
                                  DemoSignal.bass => 'Bass',
                                  DemoSignal.voice => 'Voice',
                                  DemoSignal.air => 'Air',
                                },
                                subtitle: switch (signal) {
                                  DemoSignal.bass => '90 Hz',
                                  DemoSignal.voice => '180–1.4k Hz',
                                  DemoSignal.air => '3.6–7.2k Hz',
                                },
                                selected: _signal == signal,
                                onTap: () => setState(() => _signal = signal),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Synthetic demo signal\nVisual preview · no audio playback.',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 11,
                            height: 1.6,
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: _playing ? 'Pause signal' : 'Resume signal',
                        onPressed: () => setState(() => _playing = !_playing),
                        icon: Icon(
                          _playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF253D35),
                          foregroundColor: _mint,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Choice extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _Choice({
    required this.label,
    this.subtitle,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: MediaQuery.maybeOf(context)?.disableAnimations == true
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF243E34) : const Color(0xFF131F1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFF436453)
                  : const Color(0xFF22302D),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: selected ? _mint : _muted),
                    const SizedBox(width: 7),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? _mint : _muted,
                      ),
                    ),
                  ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 10,
                    color: selected ? _mint.withValues(alpha: 0.7) : _muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
