# Waveforms Audio

Flutter audio visualizers: frequency-reactive orbs, layered waves, centered and
upward spectrum bars, voice bars, halos, and classic linear/circular/oval waveforms. No runtime dependencies beyond Flutter.

## Natural, frequency-driven motion

`ReactiveAudioVisualizer` analyzes real PCM samples with a rolling Hann-windowed FFT.
Bass (60–250 Hz) expands the orb, mids (250 Hz–2 kHz) deform its surface, and treble
(2 kHz up to 16 kHz, limited by the source sample rate) adds smaller ripples.
The spectrum view displays logarithmic frequency bands from low to high.

A fast attack and slower release make sounds feel responsive without snapping.
Quiet signals stay quiet; silence returns the visualization to rest. Rendering
updates through a painter listenable rather than rebuilding the widget every frame.

```dart
import 'package:waveforms_audio/waveforms_audio.dart';

ReactiveAudioVisualizer(
  audioStream: monoPcmStream, // Stream<List<double>>, normalized signed PCM (-1–1)
  sampleRate: 48000,         // Must match your audio source
  style: ReactiveVisualizerStyle.upwardBars,
  // Optional: omit to keep the active palette during silence.
  // inactiveColor: Colors.grey,
  attack: const Duration(milliseconds: 45),
  release: const Duration(milliseconds: 320),
  size: const Size(double.infinity, 300),
)
```

### Styles and resting colors

| Style | Motion |
| --- | --- |
| `orb` | Smooth, layered sphere shaped by bass, voice, and high frequencies. |
| `wave` | Flowing ribbons with tapered edges. |
| `bars` | Rounded frequency bars that grow above and below the center. |
| `upwardBars` | Rounded frequency bars that rise from a fixed bottom baseline. |
| `voiceBars` | Five rounded voice bars that settle into small pills. |
| `halo` | A segmented ring with mirrored frequency response. |

All six styles keep their active palette during silence by default, on both
`ReactiveAudioVisualizer` and `VoiceChatVisualizer`. `inactiveColor` is optional
and defaults to null. Set it explicitly (for example, `Colors.grey`) to fade to a
separate resting color as sound subsides. Each spectrum bar or halo segment then
follows its own frequency energy. Set it back to null to restore the active
palette at rest. Use equal primary and secondary colors for a solid color.

Connect decoded mono PCM from your recorder or player. This package does not record,
play, or decode audio. Encoded file bytes, per-chunk peaks, and precomputed frequency
magnitudes are not PCM. Downmix multichannel audio before passing it in.

- `fftSize`: power of two from 256 to 8192; default 2048. Larger windows resolve
  lower frequencies more precisely but respond more slowly.
- `bandCount`: 3–128; default 32.
- `sampleRate`: at least 8000 Hz; use the source's actual rate, not the UI refresh rate.
- `color` / `secondaryColor`: active gradient colors.
- `inactiveColor`: optional resting color; defaults to null (keep the active palette).
- A gap longer than 220 ms (or 1.5 times the last chunk's duration, whichever is
  greater) starts the release to silence. Small, regular chunks work best.
- System reduced motion disables the continuous animation and the orb's deformation;
  functional frequency levels still update. Tickers stop after settling and follow
  Flutter's `TickerMode` when hidden.

Frequency extraction follows the usual FFT-based visualization approach described
in [MDN's audio visualization guide](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API/Visualizations_with_Web_Audio_API).
The Dart implementation runs locally and does not depend on Web Audio.

## Voice chat: local and remote speakers

Use `VoiceChatVisualizer` when the color identifies who is speaking:

- `VoiceChatSpeaker.local`: blue → cyan.
- `VoiceChatSpeaker.remote`: red → orange (another participant or an AI).

Override either speaker's active gradient with `localColor`, `localSecondaryColor`,
`remoteColor`, and `remoteSecondaryColor`. Omitted or null colors keep their
individual preset defaults. Overrides apply to orb, wave, and spectrum styles
and retain the smooth transition between speakers.

The role transition takes 240 ms and respects reduced motion. Set the role from
chat state, active-speaker events, or playback state. Frequency analysis animates
the sound; it does not identify people or decide whether a voice is human or AI.

```dart
VoiceChatVisualizer(
  // These are separate, live broadcast PCM streams owned by the chat app.
  audioStream: isRemoteSpeaking ? remotePlaybackPcm : microphonePcm,
  sampleRate: isRemoteSpeaking ? remoteSampleRate : microphoneSampleRate,
  speaker: isRemoteSpeaking
      ? VoiceChatSpeaker.remote
      : VoiceChatSpeaker.local,
  style: ReactiveVisualizerStyle.orb, // wave and bars use the same role colors
  // Optional custom speaker gradients:
  localColor: Colors.purple,
  localSecondaryColor: Colors.pinkAccent,
  remoteColor: Colors.green,
  remoteSecondaryColor: Colors.limeAccent,
  // Optional resting-color override:
  // inactiveColor: Colors.blueGrey,
)
```

Create the streams once outside `build`. They must support repeated subscriptions
when switching speakers and deliver current audio, without replaying old buffered
chunks. Tap the decoded remote/AI audio **as it plays**, not an entire TTS response
as soon as it arrives over the network. Supply each source's actual sample rate.
Compressed network packets need decoding first; stereo needs downmixing to mono.

For simultaneous speakers, render two `VoiceChatVisualizer` widgets, one per feed.
For a single shared orb, your app chooses which speaker takes priority. Connect
the microphone track and remote playback separately; microphone pickup of speaker
sound is not a substitute for the remote stream.

`Pcm16Decoder` converts raw signed little-endian mono PCM16 bytes to normalized
samples and preserves sample pairs across split byte chunks:

```dart
final decoder = Pcm16Decoder();
final pcm = pcm16ByteStream.map(decoder.addBytes);
```

The main package does not record or play audio; the example uses the
[`record` plugin](https://pub.dev/packages/record) for microphone capture.

## Classic waveforms

`AudioVisualizer` draws preprocessed amplitude data. `LiveAudioVisualizer` displays
a scrolling history of per-chunk peaks. These APIs remain available for waveform
views rather than frequency analysis.

```dart
AudioVisualizer(
  audioData: AudioProcessor.extractPeaks(samples, 100),
  type: VisualizerType.circular,
  animatePulsate: true,
  transitionDuration: const Duration(milliseconds: 100),
)
```

## Try the demo

```sh
cd example
flutter run
```

1. Select **Microphone**, tap **Start microphone**, and grant access.
2. Speak normally. Choose any of the six styles to visualize your voice.
3. Select **You** for blue–cyan or **Other / AI** for red–orange. These buttons
   preview roles with the same microphone; no remote participant or AI is connected.
4. Expand **Colors** to try speaker, violet, or emerald active palettes and
   optional gray, slate, or rose resting colors. **Keep active color** is the default.
5. Tap **Stop microphone** to release capture. Capture also stops when the app
   enters the background; resuming the app does not restart it automatically.

Audio is processed locally in memory. The example does not save or upload it,
play microphone audio back, or connect to an AI service.

Select **Demo signal** for the existing Bass, Voice, and Air comparisons without
microphone access. The synthetic voice profile is not recorded speech.

Android microphone permission, iOS/macOS purpose strings, and macOS audio-input
entitlements are configured in the example. On web, use localhost or HTTPS and
allow browser microphone access. After adding this native plugin, fully rebuild
the example; hot reload alone cannot register it. See the `record` plugin's
platform setup for system requirements, including Linux audio tools.

## Checks

```sh
flutter analyze
flutter test
cd example
flutter test
```
