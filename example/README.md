# Waveforms voice demo

Run `flutter run`, select **Microphone**, then tap **Start microphone** and grant
permission. Speak to drive any of the six styles with real microphone PCM.
Choose Orb, Wave, Spectrum, Up bars, Voice bars, or Halo. Expand **Colors** to
customize the active palette and an optional resting color. **Keep active color**
is the default, preserving the active palette during silence.

Choose **You** (blue–cyan) or **Other / AI** (red–orange) to preview chat roles.
Both previews use your microphone. An actual chat integration supplies separate
local and decoded remote playback streams to `VoiceChatVisualizer`.

Capture is local and in memory; nothing is saved, uploaded, or played back.
Stop manually or background the app to release the microphone. The **Demo signal**
mode remains available without microphone access.

Fully restart/rebuild after adding native plugins. Web microphone input requires
localhost or HTTPS. See the package README for the voice-chat integration API.
