/// Fixture data minimal untuk test domain — nilai yang realistik mengikut
/// struktur repo data (bukan snapshot; domain mesti bekerja dengan mana-mana
/// nilai sah daripada data).
library;

import 'package:meridian_tycoon_app/data/models.dart';

Balance testBalance() => const Balance(
      dataVersion: '1.0.0',
      auctionFeePct: 2.0,
      auctionStartPctOfNT: 95.0,
      leverageMaxPct: 40.0,
      leverageInterestWeeklyPct: 8.0,
      leverageCapDailyNetMultiplier: 2.0,
      auctionDurationHours: 8.0,
      offlineCapHours: 8.0,
      upgradeCostGrowth: 1.15,
      purchasedCompanyNetContributionPct: 35.0,
      lostTargetRespawnHours: 48.0,
      legacyPremiumMinPct: 15.0,
      legacyPremiumMaxPct: 25.0,
      calibration: Calibration(
        activeHoursPerDay: 16,
        salaryShareOfGrossPct: 20,
        companyCoverageOfTargetPct: 30,
        opsCoverageOfTargetPct: 100,
        tolerancePct: 15,
      ),
      currencies: [],
    );

List<Tier> testTiers() => [
      for (var i = 1; i <= 8; i++)
        Tier(
          id: 't$i',
          titleKey: 'tier.t$i.title',
          maxOperations: 3 * i,
          maxStaff: 4 + 2 * i,
          baseValueA: 40000 * (1 << (i - 1)),
          targetDailyNetIncome: 6000 * (1 << (i - 1)),
          reputationThreshold: i == 1 ? null : 10 * (i - 1),
          tierUpRewardDP: i == 1 ? null : 10 * (i - 1),
          rewardKey: i == 1 ? null : 'tier.t$i.reward',
        ),
    ];

Operation testOp({String id = 'op_app_1', int unlockTier = 1}) => Operation(
      id: id,
      sector: 'app',
      unlockTier: unlockTier,
      nameKey: 'op.$id.name',
      descKey: 'op.$id.desc',
      baseCost: 23890,
      costGrowth: 1.15,
      baseIncomePerHour: 159.27,
      incomeGrowthPerLevel: 1.093,
      maxLevel: 10,
    );

Company testCompany({String id = 'co_app_t1_01', int tier = 1, String? category}) =>
    Company(
      id: id,
      nameKey: 'co.$id.name',
      sector: 'app',
      tier: tier,
      category:
          category ?? (tier == 1 ? 'starter' : tier <= 3 ? 'midmarket' : tier <= 5 ? 'rare' : 'mega'),
      grossIncomePerHourK: 0.33 * tier,
      reputation: 35,
      foundedYear: 1992,
      hqCityKey: 'city.pulau_anggerik_malam',
      staffCount: 19,
      descKey: 'co.$id.desc',
      historyKey: 'co.$id.history',
      tags: const ['fast_growth'],
      synergySector: 'logistics',
      ntValue: 49818 * tier,
      auctionStartPriceTM: 47327 * tier,
      paybackDays: 17.07,
    );

AiCeo testCeo(String id,
    {double aggression = 0.5,
    double maxPremium = 0.2,
    double increment = 4.0,
    int delay = 20,
    List<String> fav = const ['app'],
    bool boss = false}) {
  return AiCeo(
    id: id,
    profile: 'test',
    aggression: aggression,
    maxPremiumOverNT: maxPremium,
    bidIncrementPct: increment,
    entryDelayMinutes: delay,
    favoriteSectors: fav,
    tierSpeed: 'steady',
    auctionBoss: boss,
    nameKey: 'ceo.$id.name',
    bioKey: 'ceo.$id.bio',
  );
}
