## 0.0.1

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
