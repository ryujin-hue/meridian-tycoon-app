/// Pitch Pelabur (Peraturan I).
/// Kebarangkalian = clamp(0.30 + 0.006 x reputasi + modifier, 0.30, 0.90).
/// Ganjaran DP ikut tier: 10 x tier (DECISIONS.md D8 — tiada jadual dalam data).
library;

import 'rng.dart';

class PitchAngle {
  final String id; // growth | safety | story
  final double modifier;
  final String conditionDesc;
  const PitchAngle(this.id, this.modifier, this.conditionDesc);
}

const List<PitchAngle> kPitchAngles = [
  PitchAngle('growth', 0.05, 'ui.app.pitch.growth.cond'),
  PitchAngle('safety', 0.05, 'ui.app.pitch.safety.cond'),
  PitchAngle('story', 0.05, 'ui.app.pitch.story.cond'),
];

double pitchProbability({
  required double reputation,
  required PitchAngle angle,
  required bool growthConditionMet,
  required bool safetyConditionMet,
  required bool storyConditionMet,
}) {
  final condMet = switch (angle.id) {
    'growth' => growthConditionMet,
    'safety' => safetyConditionMet,
    'story' => storyConditionMet,
    _ => false,
  };
  final p = 0.30 + 0.006 * reputation + (condMet ? angle.modifier : 0.0);
  return p.clamp(0.30, 0.90);
}

bool rollPitch(double probability, int seed) => SeededRng(seed).chance(probability);

int pitchDPReward(int tierIndex0) => 10 * (tierIndex0 + 1);

/// Cooldown 24 jam (GDD Peraturan I) — keputusan mekanik GDD, bukan nombor data.
const Duration kPitchCooldown = Duration(hours: 24);
