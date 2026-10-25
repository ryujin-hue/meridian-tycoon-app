/// GameState tak berubah (Riverpod). Semua medan boleh diserialisasi ke JSON
/// (save berversi). Snapshot medan penting disimpan untuk keserasian data
/// baharu (Peraturan keserasian save — DECISIONS.md).
library;

import '../domain/auction.dart';

class OpSlot {
  final String opId;
  final int level;
  const OpSlot(this.opId, this.level);
  OpSlot upgraded() => OpSlot(opId, level + 1);
  Map<String, dynamic> toJson() => {'opId': opId, 'level': level};
  factory OpSlot.fromJson(Map<String, dynamic> j) =>
      OpSlot(j['opId'] as String, (j['level'] as num).toInt());
}

class OwnedCompany {
  final AuctionTargetSnapshot snap;
  final int integrationLevel; // 1-5
  final int acquiredMinute;
  final int weekScore; // penunjuk prestasi minguan
  const OwnedCompany(this.snap, this.integrationLevel, this.acquiredMinute,
      [this.weekScore = 0]);
  OwnedCompany withIntegration(int lvl) =>
      OwnedCompany(snap, lvl.clamp(1, 5), acquiredMinute, weekScore);
  OwnedCompany withWeekScore(int s) =>
      OwnedCompany(snap, integrationLevel, acquiredMinute, s);
  Map<String, dynamic> toJson() => {
        'snap': snap.toJson(),
        'integrationLevel': integrationLevel,
        'acquiredMinute': acquiredMinute,
        'weekScore': weekScore,
      };
  factory OwnedCompany.fromJson(Map<String, dynamic> j) => OwnedCompany(
        AuctionTargetSnapshot.fromJson(j['snap'] as Map<String, dynamic>),
        (j['integrationLevel'] as num).toInt(),
        (j['acquiredMinute'] as num).toInt(),
        (j['weekScore'] as num? ?? 0).toInt(),
      );
}

class HiredStaff {
  final String staffId;
  final String roleId;
  final int star;
  final int hiredMinute;
  const HiredStaff(this.staffId, this.roleId, this.star, this.hiredMinute);
  Map<String, dynamic> toJson() => {
        'staffId': staffId, 'roleId': roleId, 'star': star,
        'hiredMinute': hiredMinute,
      };
  factory HiredStaff.fromJson(Map<String, dynamic> j) => HiredStaff(
        j['staffId'] as String,
        j['roleId'] as String,
        (j['star'] as num).toInt(),
        (j['hiredMinute'] as num).toInt(),
      );
}

class MarketTarget {
  final AuctionTargetSnapshot snap;
  final int visibleUntilMinute;
  const MarketTarget(this.snap, this.visibleUntilMinute);
  Map<String, dynamic> toJson() =>
      {'snap': snap.toJson(), 'visibleUntilMinute': visibleUntilMinute};
  factory MarketTarget.fromJson(Map<String, dynamic> j) => MarketTarget(
        AuctionTargetSnapshot.fromJson(j['snap'] as Map<String, dynamic>),
        (j['visibleUntilMinute'] as num).toInt(),
      );
}

class ActiveNews {
  final String id;
  final String titleKey;
  final double pct; // + multiplier / - penalti
  final int endsMinute;
  final bool penalty;
  const ActiveNews(this.id, this.titleKey, this.pct, this.endsMinute,
      [this.penalty = false]);
  Map<String, dynamic> toJson() => {
        'id': id, 'titleKey': titleKey, 'pct': pct, 'endsMinute': endsMinute,
        'penalty': penalty,
      };
  factory ActiveNews.fromJson(Map<String, dynamic> j) => ActiveNews(
        j['id'] as String,
        j['titleKey'] as String,
        (j['pct'] as num).toDouble(),
        (j['endsMinute'] as num).toInt(),
        j['penalty'] as bool? ?? false,
      );
}

class DebtState {
  final int principal;
  final int lastInterestWeekKey;
  const DebtState(this.principal, this.lastInterestWeekKey);
  DebtState withPrincipal(int p) => DebtState(p, lastInterestWeekKey);
  Map<String, dynamic> toJson() =>
      {'principal': principal, 'lastInterestWeekKey': lastInterestWeekKey};
  factory DebtState.fromJson(Map<String, dynamic> j) => DebtState(
        (j['principal'] as num).toInt(),
        (j['lastInterestWeekKey'] as num).toInt(),
      );
}

class SettingsState {
  final String lang; // en | ms | id
  final bool darkMode;
  final bool sound;
  final bool vibrate;
  final bool notifications;
  final bool reduceMotion;
  const SettingsState({
    this.lang = 'ms',
    this.darkMode = true,
    this.sound = true,
    this.vibrate = true,
    this.notifications = false, // pemasaran mati; hasil ikut kebenaran
    this.reduceMotion = false,
  });
  SettingsState copyWith({
    String? lang, bool? darkMode, bool? sound, bool? vibrate,
    bool? notifications, bool? reduceMotion,
  }) =>
      SettingsState(
        lang: lang ?? this.lang,
        darkMode: darkMode ?? this.darkMode,
        sound: sound ?? this.sound,
        vibrate: vibrate ?? this.vibrate,
        notifications: notifications ?? this.notifications,
        reduceMotion: reduceMotion ?? this.reduceMotion,
      );
  Map<String, dynamic> toJson() => {
        'lang': lang, 'darkMode': darkMode, 'sound': sound, 'vibrate': vibrate,
        'notifications': notifications, 'reduceMotion': reduceMotion,
      };
  factory SettingsState.fromJson(Map<String, dynamic> j) => SettingsState(
        lang: j['lang'] as String? ?? 'ms',
        darkMode: j['darkMode'] as bool? ?? true,
        sound: j['sound'] as bool? ?? true,
        vibrate: j['vibrate'] as bool? ?? true,
        notifications: j['notifications'] as bool? ?? false,
        reduceMotion: j['reduceMotion'] as bool? ?? false,
      );
}

class GameStats {
  final int collectTotal;
  final int auctionsWon;
  final int auctionsLost;
  final int pitchesWon;
  final int pitchesLost;
  const GameStats({
    this.collectTotal = 0,
    this.auctionsWon = 0,
    this.auctionsLost = 0,
    this.pitchesWon = 0,
    this.pitchesLost = 0,
  });
  GameStats copyWith({
    int? collectTotal, int? auctionsWon, int? auctionsLost,
    int? pitchesWon, int? pitchesLost,
  }) =>
      GameStats(
        collectTotal: collectTotal ?? this.collectTotal,
        auctionsWon: auctionsWon ?? this.auctionsWon,
        auctionsLost: auctionsLost ?? this.auctionsLost,
        pitchesWon: pitchesWon ?? this.pitchesWon,
        pitchesLost: pitchesLost ?? this.pitchesLost,
      );
  Map<String, dynamic> toJson() => {
        'collectTotal': collectTotal, 'auctionsWon': auctionsWon,
        'auctionsLost': auctionsLost, 'pitchesWon': pitchesWon,
        'pitchesLost': pitchesLost,
      };
  factory GameStats.fromJson(Map<String, dynamic> j) => GameStats(
        collectTotal: (j['collectTotal'] as num? ?? 0).toInt(),
        auctionsWon: (j['auctionsWon'] as num? ?? 0).toInt(),
        auctionsLost: (j['auctionsLost'] as num? ?? 0).toInt(),
        pitchesWon: (j['pitchesWon'] as num? ?? 0).toInt(),
        pitchesLost: (j['pitchesLost'] as num? ?? 0).toInt(),
      );
}

/// Rekod lelongan selesai (untuk Overnight Summary; simpan 12 terkini).
class FinishedAuctionRecord {
  final String targetId;
  final String nameKey;
  final bool won;
  final String? winnerCeoId;
  final int finalPrice;
  final int minute;
  const FinishedAuctionRecord(this.targetId, this.nameKey, this.won,
      this.winnerCeoId, this.finalPrice, this.minute);
  Map<String, dynamic> toJson() => {
        'targetId': targetId, 'nameKey': nameKey, 'won': won,
        'winnerCeoId': winnerCeoId, 'finalPrice': finalPrice, 'minute': minute,
      };
  factory FinishedAuctionRecord.fromJson(Map<String, dynamic> j) =>
      FinishedAuctionRecord(
        j['targetId'] as String,
        j['nameKey'] as String,
        j['won'] as bool,
        j['winnerCeoId'] as String?,
        (j['finalPrice'] as num).toInt(),
        (j['minute'] as num).toInt(),
      );
}

class GameState {
  final int saveVersion;
  final String dataVersionAtSave;

  // Identiti & tier
  final String ceoName;
  final String ceoSector;
  final int tierIndex0; // 0-7
  final double reputation; // 0-100
  final int tm;
  final int dp;
  final int km;

  // Operasi
  final List<OpSlot> ops; // slot terisi (maks tier.maxOperations)
  final int lastCollectMinute;

  // Pasar & lelongan
  final List<MarketTarget> market;
  final List<AuctionState> auctions;
  final List<FinishedAuctionRecord> finished; // terkini dahulu
  final Map<String, int> lostRespawn; // companyId -> respawnMinute
  final Map<String, int> scanReveal; // companyId -> untilMinute
  final int lastMarketRefreshMinute;

  // Portfolio
  final List<OwnedCompany> companies;

  // Staf
  final List<HiredStaff> staff;
  final Map<String, int> skillCooldown; // staffId -> untilMinute
  final int lastSalaryDebitDayKey;

  // Research (nodeId -> stage dibeli)
  final Map<String, int> research;

  // Hutang
  final DebtState debt;

  // Pitch
  final int lastPitchMinute;
  final int pitchSlotCount;

  // Milestone / LiveOps / liga
  final List<String> claimedMilestones;
  final List<String> claimedLiveOps;
  final int weekScore;
  final int currentWeekKey;
  final String? weeklyTargetId;
  final int weeklyTargetProgress;
  final String? dailyContractId;
  final int dailyContractProgress;
  final int dailyContractDayKey;

  // Kesan aktif
  final List<ActiveNews> activeNews;

  // Tutorial & meta
  final int tutorialStep; // 1..10, 11 = selesai
  final int rngSeed;
  final int createdAtMinute;
  final int lastSeenMinute;
  final int notifCountDayKey;
  final int notifCount;
  final GameStats stats;
  final SettingsState settings;

  const GameState({
    this.saveVersion = 3,
    this.dataVersionAtSave = '0.0.0',
    this.ceoName = '',
    this.ceoSector = 'app',
    this.tierIndex0 = 0,
    this.reputation = 5,
    this.tm = 0,
    this.dp = 0,
    this.km = 0,
    this.ops = const [],
    this.lastCollectMinute = 0,
    this.market = const [],
    this.auctions = const [],
    this.finished = const [],
    this.lostRespawn = const {},
    this.scanReveal = const {},
    this.lastMarketRefreshMinute = 0,
    this.companies = const [],
    this.staff = const [],
    this.skillCooldown = const {},
    this.lastSalaryDebitDayKey = -1,
    this.research = const {},
    this.debt = const DebtState(0, 0),
    this.lastPitchMinute = -100000,
    this.pitchSlotCount = 1,
    this.claimedMilestones = const [],
    this.claimedLiveOps = const [],
    this.weekScore = 0,
    this.currentWeekKey = 0,
    this.weeklyTargetId,
    this.weeklyTargetProgress = 0,
    this.dailyContractId,
    this.dailyContractProgress = 0,
    this.dailyContractDayKey = -1,
    this.activeNews = const [],
    this.tutorialStep = 1,
    this.rngSeed = 20261025,
    this.createdAtMinute = 0,
    this.lastSeenMinute = 0,
    this.notifCountDayKey = -1,
    this.notifCount = 0,
    this.stats = const GameStats(),
    this.settings = const SettingsState(),
  });

  GameState copyWith({
    String? dataVersionAtSave,
    String? ceoName,
    String? ceoSector,
    int? tierIndex0,
    double? reputation,
    int? tm,
    int? dp,
    int? km,
    List<OpSlot>? ops,
    int? lastCollectMinute,
    List<MarketTarget>? market,
    List<AuctionState>? auctions,
    List<FinishedAuctionRecord>? finished,
    Map<String, int>? lostRespawn,
    Map<String, int>? scanReveal,
    int? lastMarketRefreshMinute,
    List<OwnedCompany>? companies,
    List<HiredStaff>? staff,
    Map<String, int>? skillCooldown,
    int? lastSalaryDebitDayKey,
    Map<String, int>? research,
    DebtState? debt,
    int? lastPitchMinute,
    int? pitchSlotCount,
    List<String>? claimedMilestones,
    List<String>? claimedLiveOps,
    int? weekScore,
    int? currentWeekKey,
    String? weeklyTargetId,
    bool clearWeeklyTarget = false,
    int? weeklyTargetProgress,
    String? dailyContractId,
    bool clearDailyContract = false,
    int? dailyContractProgress,
    int? dailyContractDayKey,
    List<ActiveNews>? activeNews,
    int? tutorialStep,
    int? rngSeed,
    int? lastSeenMinute,
    int? notifCountDayKey,
    int? notifCount,
    GameStats? stats,
    SettingsState? settings,
  }) =>
      GameState(
        saveVersion: saveVersion,
        dataVersionAtSave: dataVersionAtSave ?? this.dataVersionAtSave,
        ceoName: ceoName ?? this.ceoName,
        ceoSector: ceoSector ?? this.ceoSector,
        tierIndex0: tierIndex0 ?? this.tierIndex0,
        reputation: reputation ?? this.reputation,
        tm: tm ?? this.tm,
        dp: dp ?? this.dp,
        km: km ?? this.km,
        ops: ops ?? this.ops,
        lastCollectMinute: lastCollectMinute ?? this.lastCollectMinute,
        market: market ?? this.market,
        auctions: auctions ?? this.auctions,
        finished: finished ?? this.finished,
        lostRespawn: lostRespawn ?? this.lostRespawn,
        scanReveal: scanReveal ?? this.scanReveal,
        lastMarketRefreshMinute:
            lastMarketRefreshMinute ?? this.lastMarketRefreshMinute,
        companies: companies ?? this.companies,
        staff: staff ?? this.staff,
        skillCooldown: skillCooldown ?? this.skillCooldown,
        lastSalaryDebitDayKey: lastSalaryDebitDayKey ?? this.lastSalaryDebitDayKey,
        research: research ?? this.research,
        debt: debt ?? this.debt,
        lastPitchMinute: lastPitchMinute ?? this.lastPitchMinute,
        pitchSlotCount: pitchSlotCount ?? this.pitchSlotCount,
        claimedMilestones: claimedMilestones ?? this.claimedMilestones,
        claimedLiveOps: claimedLiveOps ?? this.claimedLiveOps,
        weekScore: weekScore ?? this.weekScore,
        currentWeekKey: currentWeekKey ?? this.currentWeekKey,
        weeklyTargetId:
            clearWeeklyTarget ? null : (weeklyTargetId ?? this.weeklyTargetId),
        weeklyTargetProgress: weeklyTargetProgress ?? this.weeklyTargetProgress,
        dailyContractId: clearDailyContract
            ? null
            : (dailyContractId ?? this.dailyContractId),
        dailyContractProgress: dailyContractProgress ?? this.dailyContractProgress,
        dailyContractDayKey: dailyContractDayKey ?? this.dailyContractDayKey,
        activeNews: activeNews ?? this.activeNews,
        tutorialStep: tutorialStep ?? this.tutorialStep,
        rngSeed: rngSeed ?? this.rngSeed,
        createdAtMinute: createdAtMinute,
        lastSeenMinute: lastSeenMinute ?? this.lastSeenMinute,
        notifCountDayKey: notifCountDayKey ?? this.notifCountDayKey,
        notifCount: notifCount ?? this.notifCount,
        stats: stats ?? this.stats,
        settings: settings ?? this.settings,
      );

  Map<String, dynamic> toJson() => {
        'saveVersion': saveVersion,
        'dataVersionAtSave': dataVersionAtSave,
        'ceoName': ceoName,
        'ceoSector': ceoSector,
        'tierIndex0': tierIndex0,
        'reputation': reputation,
        'tm': tm, 'dp': dp, 'km': km,
        'ops': ops.map((e) => e.toJson()).toList(),
        'lastCollectMinute': lastCollectMinute,
        'market': market.map((e) => e.toJson()).toList(),
        'auctions': auctions.map((e) => e.toJson()).toList(),
        'finished': finished.map((e) => e.toJson()).toList(),
        'lostRespawn': lostRespawn,
        'scanReveal': scanReveal,
        'lastMarketRefreshMinute': lastMarketRefreshMinute,
        'companies': companies.map((e) => e.toJson()).toList(),
        'staff': staff.map((e) => e.toJson()).toList(),
        'skillCooldown': skillCooldown,
        'lastSalaryDebitDayKey': lastSalaryDebitDayKey,
        'research': research,
        'debt': debt.toJson(),
        'lastPitchMinute': lastPitchMinute,
        'pitchSlotCount': pitchSlotCount,
        'claimedMilestones': claimedMilestones,
        'claimedLiveOps': claimedLiveOps,
        'weekScore': weekScore,
        'currentWeekKey': currentWeekKey,
        'weeklyTargetId': weeklyTargetId,
        'weeklyTargetProgress': weeklyTargetProgress,
        'dailyContractId': dailyContractId,
        'dailyContractProgress': dailyContractProgress,
        'dailyContractDayKey': dailyContractDayKey,
        'activeNews': activeNews.map((e) => e.toJson()).toList(),
        'tutorialStep': tutorialStep,
        'rngSeed': rngSeed,
        'createdAtMinute': createdAtMinute,
        'lastSeenMinute': lastSeenMinute,
        'notifCountDayKey': notifCountDayKey,
        'notifCount': notifCount,
        'stats': stats.toJson(),
        'settings': settings.toJson(),
      };

  factory GameState.fromJson(Map<String, dynamic> j) {
    final ver = (j['saveVersion'] as num? ?? 3).toInt();
    if (ver > 3) {
      // Save dari app lebih baharu: muat apa yang boleh (toleransi).
    }
    return GameState(
      saveVersion: 3,
      dataVersionAtSave: j['dataVersionAtSave'] as String? ?? '0.0.0',
      ceoName: j['ceoName'] as String? ?? '',
      ceoSector: j['ceoSector'] as String? ?? 'app',
      tierIndex0: (j['tierIndex0'] as num? ?? 0).toInt(),
      reputation: (j['reputation'] as num? ?? 5).toDouble(),
      tm: (j['tm'] as num? ?? 0).toInt(),
      dp: (j['dp'] as num? ?? 0).toInt(),
      km: (j['km'] as num? ?? 0).toInt(),
      ops: ((j['ops'] as List?) ?? const [])
          .map((e) => OpSlot.fromJson(e as Map<String, dynamic>))
          .toList(),
      lastCollectMinute: (j['lastCollectMinute'] as num? ?? 0).toInt(),
      market: ((j['market'] as List?) ?? const [])
          .map((e) => MarketTarget.fromJson(e as Map<String, dynamic>))
          .toList(),
      auctions: ((j['auctions'] as List?) ?? const [])
          .map((e) => AuctionState.fromJson(e as Map<String, dynamic>))
          .toList(),
      finished: ((j['finished'] as List?) ?? const [])
          .map((e) => FinishedAuctionRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      lostRespawn: _intMap(j['lostRespawn']),
      scanReveal: _intMap(j['scanReveal']),
      lastMarketRefreshMinute: (j['lastMarketRefreshMinute'] as num? ?? 0).toInt(),
      companies: ((j['companies'] as List?) ?? const [])
          .map((e) => OwnedCompany.fromJson(e as Map<String, dynamic>))
          .toList(),
      staff: ((j['staff'] as List?) ?? const [])
          .map((e) => HiredStaff.fromJson(e as Map<String, dynamic>))
          .toList(),
      skillCooldown: _intMap(j['skillCooldown']),
      lastSalaryDebitDayKey: (j['lastSalaryDebitDayKey'] as num? ?? -1).toInt(),
      research: _intMap(j['research']),
      debt: j['debt'] == null
          ? const DebtState(0, 0)
          : DebtState.fromJson(j['debt'] as Map<String, dynamic>),
      lastPitchMinute: (j['lastPitchMinute'] as num? ?? -100000).toInt(),
      pitchSlotCount: (j['pitchSlotCount'] as num? ?? 1).toInt(),
      claimedMilestones: ((j['claimedMilestones'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      claimedLiveOps: ((j['claimedLiveOps'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      weekScore: (j['weekScore'] as num? ?? 0).toInt(),
      currentWeekKey: (j['currentWeekKey'] as num? ?? 0).toInt(),
      weeklyTargetId: j['weeklyTargetId'] as String?,
      weeklyTargetProgress: (j['weeklyTargetProgress'] as num? ?? 0).toInt(),
      dailyContractId: j['dailyContractId'] as String?,
      dailyContractProgress: (j['dailyContractProgress'] as num? ?? 0).toInt(),
      dailyContractDayKey: (j['dailyContractDayKey'] as num? ?? -1).toInt(),
      activeNews: ((j['activeNews'] as List?) ?? const [])
          .map((e) => ActiveNews.fromJson(e as Map<String, dynamic>))
          .toList(),
      tutorialStep: (j['tutorialStep'] as num? ?? 1).toInt(),
      rngSeed: (j['rngSeed'] as num? ?? 20261025).toInt(),
      createdAtMinute: (j['createdAtMinute'] as num? ?? 0).toInt(),
      lastSeenMinute: (j['lastSeenMinute'] as num? ?? 0).toInt(),
      notifCountDayKey: (j['notifCountDayKey'] as num? ?? -1).toInt(),
      notifCount: (j['notifCount'] as num? ?? 0).toInt(),
      stats: j['stats'] == null
          ? const GameStats()
          : GameStats.fromJson(j['stats'] as Map<String, dynamic>),
      settings: j['settings'] == null
          ? const SettingsState()
          : SettingsState.fromJson(j['settings'] as Map<String, dynamic>),
    );
  }

  static Map<String, int> _intMap(Object? raw) {
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k as String, (v as num).toInt()));
    }
    return {};
  }
}
