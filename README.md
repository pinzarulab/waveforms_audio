# Waveforms Audio

Frequency-reactive Flutter visualizers for voice chat, assistants, music, and
classic waveform views. Runtime code depends only on Flutter.

## Voice chat from API bytes

Describe the uncompressed PCM once. The controller decodes arbitrary byte chunk
boundaries, normalizes samples, and exposes the stream used by the visualizer.

```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:waveforms_audio/waveforms_audio.dart';

final audio = ReactiveAudioController(
  format: const AudioFormat(
    encoding: AudioEncoding.pcm16,
    sampleRate: 48000,
    channels: 1,
    endian: Endian.little,
  ),
);

// Uint8List or List<int> from a WebSocket, HTTP stream, SDK, or audio callback.
apiAudioBytes.listen(audio.addBytes);

VoiceChatVisualizer(
  controller: audio,
  speaker: VoiceChatSpeaker.remote,
  style: const VoiceVisualizerStyle.bars(
    colors: [Colors.red, Colors.orange],
    inactiveColor: null,
    barCount: 24,
    spacing: 3,
    cornerRadius: 8,
    glow: 0.25,
  ),
);
```

Call `audio.dispose()` when the owning screen or call ends.

`AudioFormat` supports:

- Signed PCM16 and PCM24.
- Float32 PCM.
- Little- and big-endian bytes.
- Interleaved mono or multichannel audio.
- Automatic multichannel averaging, or one channel selected with `channel`.

`ReactiveAudioController.addBase64` accepts plain base64 and base64 data URLs.
`addSamples` accepts already-normalized mono samples and clamps them to -1–1.

MP3, AAC, Opus, and container formats are compressed. Decode them in the host
application or playback SDK, then feed their PCM output to this package. Send
remote or AI PCM when it is played, rather than when the whole response first
arrives.

## Local and remote speakers

The default local palette is blue–cyan. The default remote or AI palette is
red–orange. Changing `speaker` animates between palettes.

```dart
VoiceChatVisualizer(
  controller: activeAudio,
  speaker: isRemoteSpeaking
      ? VoiceChatSpeaker.remote
      : VoiceChatSpeaker.local,
  localColors: const [Color(0xFF2979FF), Color(0xFF39E9FF)],
  remoteColors: const [Color(0xFFFF453A), Color(0xFFFFAA33)],
  style: const VoiceVisualizerStyle.liquidOrb(),
  onVoiceActivity: (probability) {
    // Normalized 0–1 estimate derived from level and voice-band energy.
  },
);
```

The app selects the speaker from call state, active-speaker events, or playback
state. Frequency analysis does not identify a person. For simultaneous speakers,
render one visualizer per feed, or choose which feed controls a shared visualizer.

## Normalized PCM streams

Applications that already produce mono samples can skip the controller:

```dart
ReactiveAudioVisualizer(
  audioStream: monoPcmStream, // Stream<List<double>>, signed -1–1 samples
  sampleRate: 48000,
  style: const VoiceVisualizerStyle.ribbon(
    colors: [Color(0xFF72F5D1), Color(0xFF6B8CFF)],
  ),
  motionPreset: AudioMotionPreset.voice,
);
```

The sample rate must match the audio source. It is unrelated to display refresh
rate.

## Natural motion

The rolling FFT uses logarithmic frequency bands. Motion settings provide:

- Fast bass attack, slower voice-band movement, and soft treble decay.
- Adaptive gain for quiet and loud microphones.
- Configurable RMS noise gate.
- Peak hold with gradual falloff.
- A 0–1 voice-activity estimate.
- Configurable idle breathing. Set `idleBreathing: 0` for a motionless rest.

Choose `AudioMotionPreset.voice`, `.music`, `.ambient`, or `.energetic`.
Override any value when needed:

```dart
final motion = AudioMotionSettings.preset(
  AudioMotionPreset.voice,
).copyWith(
  noiseGate: 0.01,
  idleBreathing: 0,
  peakHold: const Duration(milliseconds: 140),
);

ReactiveAudioVisualizer(
  controller: audio,
  motion: motion,
  style: const VoiceVisualizerStyle.minimalLine(),
);
```

System reduced-motion settings disable continuous deformation while preserving
the current audio state.

## GPU fragment shader

The hybrid renderer sends fluid, radial, layered, and glow-heavy styles to one
shared GPU fragment program. Audio decoding, FFT analysis, motion envelopes,
uniform updates, and frame scheduling remain on the CPU. Simple geometric
styles stay on Canvas, where shading every pixel would cost more than drawing
the primitives directly.

```dart
// Optional: start this before opening the call screen.
await precacheWaveformsAudioShaders();

VoiceChatVisualizer(
  controller: audio,
  speaker: VoiceChatSpeaker.remote,
  renderer: VoiceVisualizerRenderer.auto,
  style: const VoiceVisualizerStyle.liquidOrb(
    glow: 0.5,
    density: 1.3,
  ),
);
```

Renderer modes:

- `auto`, the default, uses a shader when the selected style supports it.
- `canvas` always uses Flutter Canvas.
- `fragmentShader` requests the shader backend and uses Canvas for styles
  without a shader.

Shader programs are cached. A visualizer reuses its `FragmentShader` between
frames. While a program loads, or if the current platform cannot create it, the
same style is drawn with its Canvas implementation.

GPU styles are `orb`, `wave`, `halo`, `ribbon`, `liquidOrb`, `pulseRings`, and
`voiceBloom`. Bars, upward bars, voice bars, mirror spectrum, dot spectrum,
capsule bars, and minimal line retain the Canvas renderer. All GPU styles have
matching Canvas fallbacks.

## Styles

| Style object | Appearance |
| --- | --- |
| `VoiceVisualizerStyle.orb` | Layered sphere shaped by bass, mids, and treble. |
| `.liquidOrb` | GPU fluid membrane with Canvas fallback. |
| `.wave` | Symmetric flowing waveform. |
| `.ribbon` | Layered strands with independent movement. |
| `.bars` | Centered rounded frequency bars. |
| `.upwardBars` | Bars fixed to a lower baseline. |
| `.voiceBars` | Compact voice-focused pills. |
| `.mirrorSpectrum` | Spectrum mirrored around the center. |
| `.capsuleBars` | Inactive tracks filled by live energy. |
| `.dotSpectrum` | Frequency dots with vertical trails. |
| `.halo` | Segmented radial spectrum. |
| `.pulseRings` | Expanding rings driven by peaks. |
| `.voiceBloom` | Radial petals driven by voice activity. |
| `.minimalLine` | A clean waveform for compact controls. |

Every style object accepts a solid or gradient `colors` list, optional
`inactiveColor`, glow, density, symmetry, and direction. Bar-based styles also
accept bar count, spacing, and corner radius.

`inactiveColor` defaults to null. Silence therefore keeps the main palette.
Set a resting color explicitly to blend each element from that color as its
frequency becomes active.

## Classic waveforms

`AudioData` takes an immutable snapshot of its samples. Changing the source
list after construction cannot silently bypass repainting.

```dart
AudioVisualizer(
  audioData: AudioProcessor.extractPeaks(samples, 100),
  type: VisualizerType.linear,
  spacing: 4,
  strokeWidth: 3,
  animatePulsate: true,
);
```

`LiveAudioVisualizer` provides a scrolling amplitude history. Classic canvas
painters are implementation details; the main library exports widgets, models,
controllers, style objects, and audio adapters.

## Demo and checks

```sh
cd example
flutter run
```

The example can use a real microphone or a synthetic bass, voice, or treble
signal. Microphone audio stays in memory and is not uploaded or saved.

```sh
flutter analyze
flutter test
cd example && flutter test
```
