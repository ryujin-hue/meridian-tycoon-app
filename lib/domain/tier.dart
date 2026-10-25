/// Syarat Naik Tier (Peraturan J): tiga meter + memiliki syarikat tier sasaran.
library;

import '../data/models.dart';

class TierMeter {
  final String id; // capacity | reputation | capital
  final double value;
  final double target;
  bool get ok => value >= target;
  const TierMeter(this.id, this.value, this.target);
}

class TierUpCheck {
  final List<TierMeter> meters;
  final bool ownsTargetTierCompany;
  final int currentTierIndex0; // 0-7
  final int targetTierIndex0;
  final int rewardDP;
  final String? rewardKey;
  bool get canTierUp =>
      meters.every((m) => m.ok) && ownsTargetTierCompany;

  const TierUpCheck(this.meters, this.ownsTargetTierCompany,
      this.currentTierIndex0, this.targetTierIndex0, this.rewardDP, this.rewardKey);
}

/// [opsSlotsFilled] = bilangan slot operasi terisi pada tier semasa.
/// [reputation] 0-100. [netWorth] = tunai + nilai NT portfolio.
/// [ownedTierIndices] = indeks tier (0-7) syarikat dimiliki.
TierUpCheck checkTierUp({
  required List<Tier> tiers,
  required int currentTierIndex0,
  required int opsSlotsFilled,
  required double reputation,
  required int netWorth,
  required Set<int> ownedTierIndices,
}) {
  final t = tiers[currentTierIndex0];
  final target = tiers[(currentTierIndex0 + 1).clamp(0, tiers.length - 1)];
  final meters = [
    TierMeter('capacity', opsSlotsFilled.toDouble(), t.maxOperations.toDouble()),
    TierMeter('reputation', reputation, (target.reputationThreshold ?? 0).toDouble()),
    TierMeter('capital', netWorth.toDouble(), target.baseValueA.toDouble()),
  ];
  return TierUpCheck(meters, ownedTierIndices.contains(currentTierIndex0 + 1),
      currentTierIndex0, currentTierIndex0 + 1, target.tierUpRewardDP ?? 0,
      target.rewardKey);
}
