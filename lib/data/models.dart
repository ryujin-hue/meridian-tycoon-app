/// Model data — cerminan eksak struktur repo data
/// (ryujin-hue/meridian-tycoon-data, game-data/*.json).
/// Dart tulen; tiada import Flutter. Nama medan mengikut Models.kt / skema.
library;

// ------------------------------------------------------------------ balance
class Calibration {
  final double activeHoursPerDay;
  final double salaryShareOfGrossPct;
  final double companyCoverageOfTargetPct;
  final int opsCoverageOfTargetPct;
  final double tolerancePct;
  const Calibration({
    required this.activeHoursPerDay,
    required this.salaryShareOfGrossPct,
    required this.companyCoverageOfTargetPct,
    required this.opsCoverageOfTargetPct,
    required this.tolerancePct,
  });
  factory Calibration.fromJson(Map<String, dynamic> j) => Calibration(
        activeHoursPerDay: (j['activeHoursPerDay'] as num).toDouble(),
        salaryShareOfGrossPct: (j['salaryShareOfGrossPct'] as num).toDouble(),
        companyCoverageOfTargetPct:
            (j['companyCoverageOfTargetPct'] as num).toDouble(),
        opsCoverageOfTargetPct: (j['opsCoverageOfTargetPct'] as num).toInt(),
        tolerancePct: (j['tolerancePct'] as num).toDouble(),
      );
}

class CurrencyDef {
  final String id;
  final String nameKey;
  final String descKey;
  final bool premium;
  const CurrencyDef(this.id, this.nameKey, this.descKey, this.premium);
  factory CurrencyDef.fromJson(Map<String, dynamic> j) => CurrencyDef(
      j['id'] as String, j['nameKey'] as String, j['descKey'] as String,
      j['premium'] as bool? ?? false);
}

class Balance {
  final String dataVersion;
  final double auctionFeePct;
  final double auctionStartPctOfNT;
  final double leverageMaxPct;
  final double leverageInterestWeeklyPct;
  final double leverageCapDailyNetMultiplier;
  final double auctionDurationHours;
  final double offlineCapHours;
  final double upgradeCostGrowth;
  final double purchasedCompanyNetContributionPct;
  final double lostTargetRespawnHours;
  final double legacyPremiumMinPct;
  final double legacyPremiumMaxPct;
  final Calibration calibration;
  final List<CurrencyDef> currencies;
  const Balance({
    required this.dataVersion,
    required this.auctionFeePct,
    required this.auctionStartPctOfNT,
    required this.leverageMaxPct,
    required this.leverageInterestWeeklyPct,
    required this.leverageCapDailyNetMultiplier,
    required this.auctionDurationHours,
    required this.offlineCapHours,
    required this.upgradeCostGrowth,
    required this.purchasedCompanyNetContributionPct,
    required this.lostTargetRespawnHours,
    required this.legacyPremiumMinPct,
    required this.legacyPremiumMaxPct,
    required this.calibration,
    required this.currencies,
  });
  factory Balance.fromJson(Map<String, dynamic> j) => Balance(
        dataVersion: j['dataVersion'] as String,
        auctionFeePct: (j['auctionFeePct'] as num).toDouble(),
        auctionStartPctOfNT: (j['auctionStartPctOfNT'] as num).toDouble(),
        leverageMaxPct: (j['leverageMaxPct'] as num).toDouble(),
        leverageInterestWeeklyPct:
            (j['leverageInterestWeeklyPct'] as num).toDouble(),
        leverageCapDailyNetMultiplier:
            (j['leverageCapDailyNetMultiplier'] as num).toDouble(),
        auctionDurationHours: (j['auctionDurationHours'] as num).toDouble(),
        offlineCapHours: (j['offlineCapHours'] as num).toDouble(),
        upgradeCostGrowth: (j['upgradeCostGrowth'] as num).toDouble(),
        purchasedCompanyNetContributionPct:
            (j['purchasedCompanyNetContributionPct'] as num).toDouble(),
        lostTargetRespawnHours: (j['lostTargetRespawnHours'] as num).toDouble(),
        legacyPremiumMinPct: (j['legacyPremiumMinPct'] as num).toDouble(),
        legacyPremiumMaxPct: (j['legacyPremiumMaxPct'] as num).toDouble(),
        calibration: Calibration.fromJson(j['calibration'] as Map<String, dynamic>),
        currencies: ((j['currencies'] as List?) ?? const [])
            .map((e) => CurrencyDef.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

// -------------------------------------------------------------------- tiers
class Tier {
  final String id;
  final String titleKey;
  final int maxOperations;
  final int maxStaff;
  final int baseValueA;
  final int targetDailyNetIncome;
  final int? reputationThreshold;
  final int? tierUpRewardDP;
  final String? rewardKey;
  const Tier({
    required this.id,
    required this.titleKey,
    required this.maxOperations,
    required this.maxStaff,
    required this.baseValueA,
    required this.targetDailyNetIncome,
    this.reputationThreshold,
    this.tierUpRewardDP,
    this.rewardKey,
  });
  factory Tier.fromJson(Map<String, dynamic> j) => Tier(
        id: j['id'] as String,
        titleKey: j['titleKey'] as String,
        maxOperations: (j['maxOperations'] as num).toInt(),
        maxStaff: (j['maxStaff'] as num).toInt(),
        baseValueA: (j['baseValueA'] as num).toInt(),
        targetDailyNetIncome: (j['targetDailyNetIncome'] as num).toInt(),
        reputationThreshold: (j['reputationThreshold'] as num?)?.toInt(),
        tierUpRewardDP: (j['tierUpRewardDP'] as num?)?.toInt(),
        rewardKey: j['rewardKey'] as String?,
      );
}

// ------------------------------------------------------------------ sectors
class Sector {
  final String id;
  final String nameKey;
  final String descKey;
  final double multiplier;
  final List<String> synergySectors;
  final String colorHex;
  const Sector({
    required this.id,
    required this.nameKey,
    required this.descKey,
    required this.multiplier,
    required this.synergySectors,
    required this.colorHex,
  });
  factory Sector.fromJson(Map<String, dynamic> j) => Sector(
        id: j['id'] as String,
        nameKey: j['nameKey'] as String,
        descKey: j['descKey'] as String,
        multiplier: (j['multiplier'] as num).toDouble(),
        synergySectors: ((j['synergySectors'] as List?) ?? const [])
            .map((e) => e as String)
            .toList(growable: false),
        colorHex: j['colorHex'] as String,
      );
}

// --------------------------------------------------------------- operations
class Operation {
  final String id;
  final String sector;
  final int unlockTier;
  final String nameKey;
  final String descKey;
  final int baseCost;
  final double costGrowth;
  final double baseIncomePerHour;
  final double incomeGrowthPerLevel;
  final int maxLevel;
  const Operation({
    required this.id,
    required this.sector,
    required this.unlockTier,
    required this.nameKey,
    required this.descKey,
    required this.baseCost,
    required this.costGrowth,
    required this.baseIncomePerHour,
    required this.incomeGrowthPerLevel,
    required this.maxLevel,
  });
  factory Operation.fromJson(Map<String, dynamic> j) => Operation(
        id: j['id'] as String,
        sector: j['sector'] as String,
        unlockTier: (j['unlockTier'] as num).toInt(),
        nameKey: j['nameKey'] as String,
        descKey: j['descKey'] as String,
        baseCost: (j['baseCost'] as num).toInt(),
        costGrowth: (j['costGrowth'] as num).toDouble(),
        baseIncomePerHour: (j['baseIncomePerHour'] as num).toDouble(),
        incomeGrowthPerLevel: (j['incomeGrowthPerLevel'] as num).toDouble(),
        maxLevel: (j['maxLevel'] as num).toInt(),
      );
}

// ---------------------------------------------------------------- companies
class Company {
  final String id;
  final String nameKey;
  final String sector;
  final int tier; // 1..8
  final String category; // starter|midmarket|rare|mega|legacy
  final double grossIncomePerHourK; // ribu TM sejam (P)
  final int reputation; // R
  final int foundedYear;
  final String hqCityKey;
  final int staffCount;
  final String descKey;
  final String historyKey;
  final List<String> tags;
  final String synergySector;
  final int ntValue;
  final int auctionStartPriceTM;
  final double paybackDays;
  final String? formerOwnerCeoId;
  final double? premiumPct;
  const Company({
    required this.id,
    required this.nameKey,
    required this.sector,
    required this.tier,
    required this.category,
    required this.grossIncomePerHourK,
    required this.reputation,
    required this.foundedYear,
    required this.hqCityKey,
    required this.staffCount,
    required this.descKey,
    required this.historyKey,
    required this.tags,
    required this.synergySector,
    required this.ntValue,
    required this.auctionStartPriceTM,
    required this.paybackDays,
    this.formerOwnerCeoId,
    this.premiumPct,
  });
  factory Company.fromJson(Map<String, dynamic> j) => Company(
        id: j['id'] as String,
        nameKey: j['nameKey'] as String,
        sector: j['sector'] as String,
        tier: (j['tier'] as num).toInt(),
        category: j['category'] as String,
        grossIncomePerHourK: (j['grossIncomePerHourK'] as num).toDouble(),
        reputation: (j['reputation'] as num).toInt(),
        foundedYear: (j['foundedYear'] as num).toInt(),
        hqCityKey: j['hqCityKey'] as String,
        staffCount: (j['staffCount'] as num).toInt(),
        descKey: j['descKey'] as String,
        historyKey: j['historyKey'] as String,
        tags: ((j['tags'] as List?) ?? const [])
            .map((e) => e as String)
            .toList(growable: false),
        synergySector: j['synergySector'] as String,
        ntValue: (j['ntValue'] as num).toInt(),
        auctionStartPriceTM: (j['auctionStartPriceTM'] as num).toInt(),
        paybackDays: (j['paybackDays'] as num).toDouble(),
        formerOwnerCeoId: j['formerOwnerCeoId'] as String?,
        premiumPct: (j['premiumPct'] as num?)?.toDouble(),
      );
}

// ------------------------------------------------------------------ ai_ceos
class AiCeo {
  final String id;
  final String profile;
  final double aggression;
  final double maxPremiumOverNT;
  final double bidIncrementPct;
  final int entryDelayMinutes;
  final List<String> favoriteSectors;
  final String tierSpeed;
  final bool auctionBoss;
  final String nameKey;
  final String bioKey;
  const AiCeo({
    required this.id,
    required this.profile,
    required this.aggression,
    required this.maxPremiumOverNT,
    required this.bidIncrementPct,
    required this.entryDelayMinutes,
    required this.favoriteSectors,
    required this.tierSpeed,
    required this.auctionBoss,
    required this.nameKey,
    required this.bioKey,
  });
  factory AiCeo.fromJson(Map<String, dynamic> j) => AiCeo(
        id: j['id'] as String,
        profile: j['profile'] as String,
        aggression: (j['aggression'] as num).toDouble(),
        maxPremiumOverNT: (j['maxPremiumOverNT'] as num).toDouble(),
        bidIncrementPct: (j['bidIncrementPct'] as num).toDouble(),
        entryDelayMinutes: (j['entryDelayMinutes'] as num).toInt(),
        favoriteSectors: ((j['favoriteSectors'] as List?) ?? const [])
            .map((e) => e as String)
            .toList(growable: false),
        tierSpeed: j['tierSpeed'] as String,
        auctionBoss: j['auctionBoss'] as bool? ?? false,
        nameKey: j['nameKey'] as String,
        bioKey: j['bioKey'] as String,
      );
}

// -------------------------------------------------------------- staff roles
class StaffPassive {
  final String statKey;
  final double perStarPct;
  final double hardCapPct;
  final String descKey;
  const StaffPassive(this.statKey, this.perStarPct, this.hardCapPct, this.descKey);
  factory StaffPassive.fromJson(Map<String, dynamic> j) => StaffPassive(
        j['statKey'] as String,
        (j['perStarPct'] as num).toDouble(),
        (j['hardCapPct'] as num).toDouble(),
        j['descKey'] as String,
      );
}

class StaffActiveSkill {
  final String skillId;
  final String nameKey;
  final String descKey;
  final int cooldownHours;
  final int unlockStar;
  const StaffActiveSkill(this.skillId, this.nameKey, this.descKey,
      this.cooldownHours, this.unlockStar);
  factory StaffActiveSkill.fromJson(Map<String, dynamic> j) => StaffActiveSkill(
        j['skillId'] as String,
        j['nameKey'] as String,
        j['descKey'] as String,
        (j['cooldownHours'] as num).toInt(),
        (j['unlockStar'] as num).toInt(),
      );
}

class StaffRole {
  final String id;
  final String nameKey;
  final String descKey;
  final StaffPassive passive;
  final StaffActiveSkill activeSkill;
  final List<int> salaryByTier; // 8 nilai, indeks tier-1
  final int hireBaseCostPerStarTM;
  final List<int> hireTierScale; // 8 nilai
  const StaffRole({
    required this.id,
    required this.nameKey,
    required this.descKey,
    required this.passive,
    required this.activeSkill,
    required this.salaryByTier,
    required this.hireBaseCostPerStarTM,
    required this.hireTierScale,
  });
  factory StaffRole.fromJson(Map<String, dynamic> j) => StaffRole(
        id: j['id'] as String,
        nameKey: j['nameKey'] as String,
        descKey: j['descKey'] as String,
        passive: StaffPassive.fromJson(j['passive'] as Map<String, dynamic>),
        activeSkill:
            StaffActiveSkill.fromJson(j['activeSkill'] as Map<String, dynamic>),
        salaryByTier: ((j['salaryByTier'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList(growable: false),
        hireBaseCostPerStarTM: (j['hireBaseCostPerStarTM'] as num).toInt(),
        hireTierScale: ((j['hireTierScale'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList(growable: false),
      );
}

class StaffMember {
  final String id;
  final String role;
  final int star;
  final String nameKey;
  final String bioKey;
  const StaffMember(this.id, this.role, this.star, this.nameKey, this.bioKey);
  factory StaffMember.fromJson(Map<String, dynamic> j) => StaffMember(
        j['id'] as String,
        j['role'] as String,
        (j['star'] as num).toInt(),
        j['nameKey'] as String,
        j['bioKey'] as String,
      );
}

// ----------------------------------------------------------------- research
class ResearchEffect {
  final String type;
  final double perStageValue;
  final double hardCapValue;
  const ResearchEffect(this.type, this.perStageValue, this.hardCapValue);
  factory ResearchEffect.fromJson(Map<String, dynamic> j) => ResearchEffect(
        j['type'] as String,
        (j['perStageValue'] as num).toDouble(),
        (j['hardCapValue'] as num).toDouble(),
      );
}

class ResearchNode {
  final String id;
  final String tree;
  final int stage;
  final String nameKey;
  final String descKey;
  final int costDP;
  final int unlockTier;
  final ResearchEffect effect;
  const ResearchNode({
    required this.id,
    required this.tree,
    required this.stage,
    required this.nameKey,
    required this.descKey,
    required this.costDP,
    required this.unlockTier,
    required this.effect,
  });
  factory ResearchNode.fromJson(Map<String, dynamic> j) => ResearchNode(
        id: j['id'] as String,
        tree: j['tree'] as String,
        stage: (j['stage'] as num).toInt(),
        nameKey: j['nameKey'] as String,
        descKey: j['descKey'] as String,
        costDP: (j['costDP'] as num).toInt(),
        unlockTier: (j['unlockTier'] as num).toInt(),
        effect: ResearchEffect.fromJson(j['effect'] as Map<String, dynamic>),
      );
}

// ------------------------------------------------------------------- events
class StockOutEvent {
  final String id;
  final String? sector;
  final String titleKey;
  final String descKey;
  final double durationHours;
  final double incomePenaltyPct;
  const StockOutEvent(this.id, this.sector, this.titleKey, this.descKey,
      this.durationHours, this.incomePenaltyPct);
  factory StockOutEvent.fromJson(Map<String, dynamic> j) => StockOutEvent(
        j['id'] as String,
        j['sector'] as String?,
        j['titleKey'] as String,
        j['descKey'] as String,
        (j['durationHours'] as num).toDouble(),
        (j['incomePenaltyPct'] as num).toDouble(),
      );
}

class BiddingWarEvent {
  final String id;
  final String titleKey;
  final String descKey;
  final double durationHours;
  final int extraCompetitorCount;
  final double aggressionBoostPct;
  const BiddingWarEvent(this.id, this.titleKey, this.descKey, this.durationHours,
      this.extraCompetitorCount, this.aggressionBoostPct);
  factory BiddingWarEvent.fromJson(Map<String, dynamic> j) => BiddingWarEvent(
        j['id'] as String,
        j['titleKey'] as String,
        j['descKey'] as String,
        (j['durationHours'] as num).toDouble(),
        (j['extraCompetitorCount'] as num).toInt(),
        (j['aggressionBoostPct'] as num).toDouble(),
      );
}

class EventGoal {
  final String type;
  final int amount;
  const EventGoal(this.type, this.amount);
  factory EventGoal.fromJson(Map<String, dynamic> j) =>
      EventGoal(j['type'] as String, (j['amount'] as num).toInt());
}

class EventReward {
  final int? tm;
  final int? dp;
  final int? km;
  final String? cosmeticRef;
  const EventReward({this.tm, this.dp, this.km, this.cosmeticRef});
  factory EventReward.fromJson(Map<String, dynamic> j) => EventReward(
        tm: (j['tm'] as num?)?.toInt(),
        dp: (j['dp'] as num?)?.toInt(),
        km: (j['km'] as num?)?.toInt(),
        cosmeticRef: j['cosmeticRef'] as String?,
      );
}

class DailyContract {
  final String id;
  final int tierBand;
  final String? sector;
  final String titleKey;
  final String descKey;
  final double durationHours;
  final EventGoal goal;
  final EventReward reward;
  const DailyContract(this.id, this.tierBand, this.sector, this.titleKey,
      this.descKey, this.durationHours, this.goal, this.reward);
  factory DailyContract.fromJson(Map<String, dynamic> j) => DailyContract(
        j['id'] as String,
        (j['tierBand'] as num).toInt(),
        j['sector'] as String?,
        j['titleKey'] as String,
        j['descKey'] as String,
        (j['durationHours'] as num).toDouble(),
        EventGoal.fromJson(j['goal'] as Map<String, dynamic>),
        EventReward.fromJson(j['reward'] as Map<String, dynamic>),
      );
}

class WeeklyTarget {
  final String id;
  final int tierBand;
  final String titleKey;
  final String descKey;
  final double durationHours;
  final EventGoal goal;
  final EventReward reward;
  const WeeklyTarget(this.id, this.tierBand, this.titleKey, this.descKey,
      this.durationHours, this.goal, this.reward);
  factory WeeklyTarget.fromJson(Map<String, dynamic> j) => WeeklyTarget(
        j['id'] as String,
        (j['tierBand'] as num).toInt(),
        j['titleKey'] as String,
        j['descKey'] as String,
        (j['durationHours'] as num).toDouble(),
        EventGoal.fromJson(j['goal'] as Map<String, dynamic>),
        EventReward.fromJson(j['reward'] as Map<String, dynamic>),
      );
}

class MarketNews {
  final String id;
  final String scope;
  final String titleKey;
  final double incomePercentPct;
  final double durationHours;
  final int weight;
  const MarketNews(this.id, this.scope, this.titleKey, this.incomePercentPct,
      this.durationHours, this.weight);
  factory MarketNews.fromJson(Map<String, dynamic> j) {
    final eff = (j['effect'] ?? const {}) as Map<String, dynamic>;
    return MarketNews(
      j['id'] as String,
      j['scope'] as String? ?? 'global',
      j['titleKey'] as String,
      (eff['incomePercentPct'] as num? ?? 0).toDouble(),
      (eff['durationHours'] as num? ?? 0).toDouble(),
      (j['weight'] as num? ?? 1).toInt(),
    );
  }
}

class MicroEvent {
  final String id;
  final String titleKey;
  final String descKey;
  final int durationMinutes;
  final String effectType;
  final double effectValue;
  final int weight;
  const MicroEvent(this.id, this.titleKey, this.descKey, this.durationMinutes,
      this.effectType, this.effectValue, this.weight);
  factory MicroEvent.fromJson(Map<String, dynamic> j) {
    final eff = (j['effect'] ?? const {}) as Map<String, dynamic>;
    return MicroEvent(
      j['id'] as String,
      j['titleKey'] as String,
      j['descKey'] as String,
      (j['durationMinutes'] as num).toInt(),
      eff['type'] as String? ?? '',
      (eff['value'] as num? ?? 0).toDouble(),
      (j['weight'] as num? ?? 1).toInt(),
    );
  }
}

class EventsData {
  final String dataVersion;
  final List<StockOutEvent> stockOut;
  final List<BiddingWarEvent> biddingWar;
  final List<DailyContract> dailyContract;
  final List<WeeklyTarget> weeklyTarget;
  final List<MarketNews> marketNews;
  final List<MicroEvent> microEvent;
  const EventsData({
    required this.dataVersion,
    required this.stockOut,
    required this.biddingWar,
    required this.dailyContract,
    required this.weeklyTarget,
    required this.marketNews,
    required this.microEvent,
  });
  factory EventsData.fromJson(Map<String, dynamic> j) => EventsData(
        dataVersion: j['dataVersion'] as String,
        stockOut: ((j['stock_out'] as List?) ?? const [])
            .map((e) => StockOutEvent.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        biddingWar: ((j['bidding_war'] as List?) ?? const [])
            .map((e) => BiddingWarEvent.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        dailyContract: ((j['daily_contract'] as List?) ?? const [])
            .map((e) => DailyContract.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        weeklyTarget: ((j['weekly_target'] as List?) ?? const [])
            .map((e) => WeeklyTarget.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        marketNews: ((j['market_news'] as List?) ?? const [])
            .map((e) => MarketNews.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        microEvent: ((j['micro_event'] as List?) ?? const [])
            .map((e) => MicroEvent.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

// ------------------------------------------------------------------ seasons
class SeasonStep {
  final int step;
  final List<EventReward> rewards;
  const SeasonStep(this.step, this.rewards);
  factory SeasonStep.fromJson(Map<String, dynamic> j) => SeasonStep(
        (j['step'] as num).toInt(),
        ((j['rewards'] as List?) ?? const [])
            .map((e) => EventReward.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

class SeasonTrack {
  final List<SeasonStep> steps;
  const SeasonTrack(this.steps);
  factory SeasonTrack.fromJson(Map<String, dynamic> j) => SeasonTrack(
        ((j['steps'] as List?) ?? const [])
            .map((e) => SeasonStep.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

class Season {
  final String id;
  final String nameKey;
  final String descKey;
  final int weeksPerSeason;
  final double seasonMultiplier;
  final SeasonTrack freeTrack;
  final SeasonTrack? premiumTrack;
  const Season({
    required this.id,
    required this.nameKey,
    required this.descKey,
    required this.weeksPerSeason,
    required this.seasonMultiplier,
    required this.freeTrack,
    this.premiumTrack,
  });
  factory Season.fromJson(Map<String, dynamic> j) => Season(
        id: j['id'] as String,
        nameKey: j['nameKey'] as String,
        descKey: j['descKey'] as String,
        weeksPerSeason: (j['weeksPerSeason'] as num).toInt(),
        seasonMultiplier: (j['seasonMultiplier'] as num).toDouble(),
        freeTrack: SeasonTrack.fromJson(j['freeTrack'] as Map<String, dynamic>),
        premiumTrack: j['premiumTrack'] == null
            ? null
            : SeasonTrack.fromJson(j['premiumTrack'] as Map<String, dynamic>),
      );
}

// --------------------------------------------------------------- cosmetics
class Cosmetic {
  final String id;
  final String type;
  final String nameKey;
  final String descKey;
  final String fixedRarity;
  final int priceKM;
  final String? tierRef;
  const Cosmetic(this.id, this.type, this.nameKey, this.descKey, this.fixedRarity,
      this.priceKM, this.tierRef);
  factory Cosmetic.fromJson(Map<String, dynamic> j) => Cosmetic(
        j['id'] as String,
        j['type'] as String,
        j['nameKey'] as String,
        j['descKey'] as String,
        j['fixedRarity'] as String,
        (j['priceKM'] as num).toInt(),
        j['tierRef'] as String?,
      );
}

// --------------------------------------------------------------- milestones
class MilestoneGoal {
  final String type;
  final int value;
  final String? sector;
  const MilestoneGoal(this.type, this.value, this.sector);
  factory MilestoneGoal.fromJson(Map<String, dynamic> j) => MilestoneGoal(
        j['type'] as String,
        (j['value'] as num).toInt(),
        j['sector'] as String?,
      );
}

class Milestone {
  final String id;
  final bool core;
  final String nameKey;
  final String descKey;
  final MilestoneGoal goal;
  final EventReward reward;
  const Milestone(this.id, this.core, this.nameKey, this.descKey, this.goal,
      this.reward);
  factory Milestone.fromJson(Map<String, dynamic> j) => Milestone(
        j['id'] as String,
        j['core'] as bool? ?? false,
        j['nameKey'] as String,
        j['descKey'] as String,
        MilestoneGoal.fromJson(j['goal'] as Map<String, dynamic>),
        EventReward.fromJson(j['reward'] as Map<String, dynamic>),
      );
}

// ----------------------------------------------------------------- tutorial
class TutorialStep {
  final int step;
  final String id;
  final String titleKey;
  final String descKey;
  final String uiElement;
  final String requiredAction;
  final int rewardTM;
  const TutorialStep(this.step, this.id, this.titleKey, this.descKey,
      this.uiElement, this.requiredAction, this.rewardTM);
  factory TutorialStep.fromJson(Map<String, dynamic> j) => TutorialStep(
        (j['step'] as num).toInt(),
        j['id'] as String,
        j['titleKey'] as String,
        j['descKey'] as String,
        j['uiElement'] as String,
        j['requiredAction'] as String,
        (j['rewardTM'] as num? ?? 0).toInt(),
      );
}

class StarterGrant {
  final int tm;
  final String noteKey;
  const StarterGrant(this.tm, this.noteKey);
  factory StarterGrant.fromJson(Map<String, dynamic> j) =>
      StarterGrant((j['tm'] as num).toInt(), j['noteKey'] as String);
}

class StarterTarget {
  final int featuredTier;
  final int maxStartPriceTM;
  final int noAiBidsMinutes;
  final int firstPurchaseWithinMinutes;
  final String noteKey;
  const StarterTarget(this.featuredTier, this.maxStartPriceTM,
      this.noAiBidsMinutes, this.firstPurchaseWithinMinutes, this.noteKey);
  factory StarterTarget.fromJson(Map<String, dynamic> j) => StarterTarget(
        (j['featuredTier'] as num).toInt(),
        (j['maxStartPriceTM'] as num).toInt(),
        (j['noAiBidsMinutes'] as num).toInt(),
        (j['firstPurchaseWithinMinutes'] as num).toInt(),
        j['noteKey'] as String,
      );
}

class TutorialData {
  final String dataVersion;
  final List<TutorialStep> steps;
  final StarterGrant starterGrant;
  final StarterTarget starterTarget;
  const TutorialData(this.dataVersion, this.steps, this.starterGrant,
      this.starterTarget);
  factory TutorialData.fromJson(Map<String, dynamic> j) => TutorialData(
        j['dataVersion'] as String,
        ((j['steps'] as List?) ?? const [])
            .map((e) => TutorialStep.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        StarterGrant.fromJson(j['starterGrant'] as Map<String, dynamic>),
        StarterTarget.fromJson(j['starterTarget'] as Map<String, dynamic>),
      );
}

// ------------------------------------------------------------- leaderboard
class LeaderboardBot {
  final String id;
  final String nameKey;
  final int tier;
  final int weeklyScoreBase;
  final int weeklyScoreVariance;
  final String style;
  const LeaderboardBot(this.id, this.nameKey, this.tier, this.weeklyScoreBase,
      this.weeklyScoreVariance, this.style);
  factory LeaderboardBot.fromJson(Map<String, dynamic> j) => LeaderboardBot(
        j['id'] as String,
        j['nameKey'] as String,
        (j['tier'] as num).toInt(),
        (j['weeklyScoreBase'] as num).toInt(),
        (j['weeklyScoreVariance'] as num).toInt(),
        j['style'] as String,
      );
}

class LeaderboardData {
  final String dataVersion;
  final int leagueSize;
  final List<LeaderboardBot> bots;
  final List<String> namePool;
  const LeaderboardData(this.dataVersion, this.leagueSize, this.bots, this.namePool);
  factory LeaderboardData.fromJson(Map<String, dynamic> j) => LeaderboardData(
        j['dataVersion'] as String,
        (j['leagueSize'] as num).toInt(),
        ((j['bots'] as List?) ?? const [])
            .map((e) => LeaderboardBot.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        ((j['namePool'] as List?) ?? const [])
            .map((e) => e as String)
            .toList(growable: false),
      );
}

// ---------------------------------------------------------------- aggregate
/// Agregat semua data + peta i18n tiga bahasa.
class GameData {
  final Balance balance;
  final List<Tier> tiers;
  final List<Sector> sectors;
  final List<Operation> operations;
  final List<Company> companies;
  final List<AiCeo> ceos;
  final List<StaffRole> staffRoles;
  final List<StaffMember> staffPool;
  final List<ResearchNode> research;
  final EventsData events;
  final List<Season> seasons;
  final List<Cosmetic> cosmetics;
  final List<Milestone> milestones;
  final TutorialData tutorial;
  final LeaderboardData leaderboard;
  final Map<String, Map<String, String>> i18n; // lang -> key -> text
  const GameData({
    required this.balance,
    required this.tiers,
    required this.sectors,
    required this.operations,
    required this.companies,
    required this.ceos,
    required this.staffRoles,
    required this.staffPool,
    required this.research,
    required this.events,
    required this.seasons,
    required this.cosmetics,
    required this.milestones,
    required this.tutorial,
    required this.leaderboard,
    required this.i18n,
  });

  String get dataVersion => balance.dataVersion;
  Tier tier(int index0) => tiers[index0.clamp(0, tiers.length - 1)];
  Sector sector(String id) => sectors.firstWhere((s) => s.id == id,
      orElse: () => sectors.first);
}
