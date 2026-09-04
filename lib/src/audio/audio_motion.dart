/// Tuned motion profiles for common audio experiences.
enum AudioMotionPreset { voice, music, ambient, energetic }

/// Frequency-specific motion, gain, voice activity, and idle behavior.
class AudioMotionSettings {
  final Duration bassAttack;
  final Duration bassRelease;
  final Duration midsAttack;
  final Duration midsRelease;
  final Duration trebleAttack;
  final Duration trebleRelease;
  final Duration levelAttack;
  final Duration levelRelease;
  final Duration peakHold;

  /// Peak falloff in normalized units per second.
  final double peakFalloff;

  /// RMS values below this threshold are treated as silence.
  final double noiseGate;
  final bool adaptiveGain;

  /// Motion retained during silence. Zero creates a motionless rest state.
  final double idleBreathing;

  const AudioMotionSettings({
    required this.bassAttack,
    required this.bassRelease,
    required this.midsAttack,
    required this.midsRelease,
    required this.trebleAttack,
    required this.trebleRelease,
    required this.levelAttack,
    required this.levelRelease,
    this.peakHold = const Duration(milliseconds: 100),
    this.peakFalloff = 0.85,
    this.noiseGate = 0.006,
    this.adaptiveGain = true,
    this.idleBreathing = 0.025,
  }) : assert(peakFalloff > 0),
       assert(noiseGate >= 0 && noiseGate < 1),
       assert(idleBreathing >= 0 && idleBreathing <= 1);

  factory AudioMotionSettings.preset(AudioMotionPreset preset) =>
      switch (preset) {
        AudioMotionPreset.voice => const AudioMotionSettings(
          bassAttack: Duration(milliseconds: 28),
          bassRelease: Duration(milliseconds: 220),
          midsAttack: Duration(milliseconds: 52),
          midsRelease: Duration(milliseconds: 290),
          trebleAttack: Duration(milliseconds: 85),
          trebleRelease: Duration(milliseconds: 390),
          levelAttack: Duration(milliseconds: 42),
          levelRelease: Duration(milliseconds: 310),
          noiseGate: 0.007,
          idleBreathing: 0.018,
        ),
        AudioMotionPreset.music => const AudioMotionSettings(
          bassAttack: Duration(milliseconds: 18),
          bassRelease: Duration(milliseconds: 170),
          midsAttack: Duration(milliseconds: 32),
          midsRelease: Duration(milliseconds: 230),
          trebleAttack: Duration(milliseconds: 48),
          trebleRelease: Duration(milliseconds: 300),
          levelAttack: Duration(milliseconds: 28),
          levelRelease: Duration(milliseconds: 240),
          noiseGate: 0.003,
          adaptiveGain: false,
          idleBreathing: 0.012,
        ),
        AudioMotionPreset.ambient => const AudioMotionSettings(
          bassAttack: Duration(milliseconds: 110),
          bassRelease: Duration(milliseconds: 650),
          midsAttack: Duration(milliseconds: 150),
          midsRelease: Duration(milliseconds: 800),
          trebleAttack: Duration(milliseconds: 210),
          trebleRelease: Duration(milliseconds: 950),
          levelAttack: Duration(milliseconds: 130),
          levelRelease: Duration(milliseconds: 800),
          noiseGate: 0.002,
          idleBreathing: 0.055,
        ),
        AudioMotionPreset.energetic => const AudioMotionSettings(
          bassAttack: Duration(milliseconds: 10),
          bassRelease: Duration(milliseconds: 105),
          midsAttack: Duration(milliseconds: 16),
          midsRelease: Duration(milliseconds: 135),
          trebleAttack: Duration(milliseconds: 24),
          trebleRelease: Duration(milliseconds: 175),
          levelAttack: Duration(milliseconds: 14),
          levelRelease: Duration(milliseconds: 125),
          peakHold: Duration(milliseconds: 145),
          peakFalloff: 1.15,
          noiseGate: 0.004,
          idleBreathing: 0.03,
        ),
      };

  AudioMotionSettings copyWith({
    Duration? bassAttack,
    Duration? bassRelease,
    Duration? midsAttack,
    Duration? midsRelease,
    Duration? trebleAttack,
    Duration? trebleRelease,
    Duration? levelAttack,
    Duration? levelRelease,
    Duration? peakHold,
    double? peakFalloff,
    double? noiseGate,
    bool? adaptiveGain,
    double? idleBreathing,
  }) => AudioMotionSettings(
    bassAttack: bassAttack ?? this.bassAttack,
    bassRelease: bassRelease ?? this.bassRelease,
    midsAttack: midsAttack ?? this.midsAttack,
    midsRelease: midsRelease ?? this.midsRelease,
    trebleAttack: trebleAttack ?? this.trebleAttack,
    trebleRelease: trebleRelease ?? this.trebleRelease,
    levelAttack: levelAttack ?? this.levelAttack,
    levelRelease: levelRelease ?? this.levelRelease,
    peakHold: peakHold ?? this.peakHold,
    peakFalloff: peakFalloff ?? this.peakFalloff,
    noiseGate: noiseGate ?? this.noiseGate,
    adaptiveGain: adaptiveGain ?? this.adaptiveGain,
    idleBreathing: idleBreathing ?? this.idleBreathing,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioMotionSettings &&
          bassAttack == other.bassAttack &&
          bassRelease == other.bassRelease &&
          midsAttack == other.midsAttack &&
          midsRelease == other.midsRelease &&
          trebleAttack == other.trebleAttack &&
          trebleRelease == other.trebleRelease &&
          levelAttack == other.levelAttack &&
          levelRelease == other.levelRelease &&
          peakHold == other.peakHold &&
          peakFalloff == other.peakFalloff &&
          noiseGate == other.noiseGate &&
          adaptiveGain == other.adaptiveGain &&
          idleBreathing == other.idleBreathing;

  @override
  int get hashCode => Object.hash(
    bassAttack,
    bassRelease,
    midsAttack,
    midsRelease,
    trebleAttack,
    trebleRelease,
    levelAttack,
    levelRelease,
    peakHold,
    peakFalloff,
    noiseGate,
    adaptiveGain,
    idleBreathing,
  );
}
