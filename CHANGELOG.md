## 0.2.1

* Expand README with setup, lifecycle examples, and a full public API reference.
* Document public Dart constructors, parameters, methods, defaults, constraints,
  input formats, renderer fallbacks, and ownership behavior.
* Clarify resampling boundaries, style-specific options, and speaker palettes.

## 0.2.0

* Smooth wave and ribbon contours across frequency bands in both renderers.
* Redesign halo with rounded rays and bloom with a continuous petal silhouette;
  apply seamless spatial gradients across every palette stop.
* Give mirror spectrum a separated, fading reflection distinct from spectrum bars.

* Add streaming mono PCM resampling with controller output-rate selection,
  per-call source rates, and explicit tail flushing.
* Preserve up to four GPU gradient stops and use Canvas for longer palettes.
  Correct wave-layer palette positions to include the final color.

## 0.1.0

* Add a shared cross-backend fragment shader for orb, wave, halo, ribbon,
  liquid-orb, pulse-ring, and voice-bloom effects. Includes cached loading,
  automatic Canvas fallback, explicit renderer selection, and a public precache
  API.
* Add immutable audio snapshots and functional classic-bar spacing.
* Add PCM16, PCM24, and Float32 input formats with endian, multichannel,
  channel-selection, base64, and normalized-sample controller APIs.
* Add voice, music, ambient, and energetic motion presets with frequency-specific
  envelopes, adaptive gain, noise gate, peak hold, voice activity, and optional
  idle breathing.
* Add mirror spectrum, ribbon, liquid orb, pulse rings, dot spectrum, capsule
  bars, voice bloom, and minimal-line styles.
* Replace reactive constructor styling with immutable `VoiceVisualizerStyle`
  objects and keep canvas painters out of the main public entrypoint.

## 0.0.1

* Add `upwardBars`, `voiceBars`, and `halo` reactive styles.
* Add optional `inactiveColor` to reactive and voice-chat visualizers. By default,
  the active palette remains visible during silence; an explicit resting color
  enables energy-driven fading.
* Extend the example with a responsive six-style picker and active/idle palette controls.

* Allow independent local and remote gradient overrides in `VoiceChatVisualizer`,
  retaining preset defaults and smooth speaker transitions.

* Add `VoiceChatVisualizer` with smooth blue–cyan local and red–orange remote/AI
  speaker palettes, plus a reusable streaming `Pcm16Decoder`.
* Add opt-in microphone capture to the example, platform permissions, denied-access
  feedback, and cleanup on stop, background, or disposal.

* Add `ReactiveAudioVisualizer` with an organic orb, layered wave, and rounded
  logarithmic spectrum bars driven by PCM frequency energy.
* Add a rolling Hann-windowed FFT, fixed decibel scaling, and time-based
  attack/release envelopes with silence settling and reduced-motion support.
* Redesign the example with selectable frequency signals, visual styles, and pause.

* Seamless sinusoidal pulses that keep waveforms visible through the full cycle.
* Preserve animation progress during data updates and apply duration changes immediately.
* Ease amplitude updates with configurable `transitionDuration` (100 ms by default;
  use `Duration.zero` for immediate updates).
* Rotate oval waveforms as a whole and fit radial waveforms inside their bounds.
* Respect system reduced-motion settings and isolate waveform repaints.
* Reduce per-frame allocations; handle live stream replacement and window resizing.
