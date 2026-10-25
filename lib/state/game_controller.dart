/// GameController: semua tindakan pemain. Aliran satu hala:
/// UI/Adegan Flame → GameController → GameState baharu (tak berubah).
/// Deterministik: Clock & RNG diinjeksi; semua rawak dari seed dalam save.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../app/config.dart';
import '../data/data_loader.dart';
import '../data/models.dart';
import '../data/save_repository.dart';
import '../domain/auction.dart';
import '../domain/clock.dart';
import '../domain/economy.dart';
import '../domain/effects.dart';
import '../domain/leaderboard.dart';
import '../domain/liveops.dart';
import '../domain/pitch.dart';
import '../domain/rng.dart';
import '../domain/staff.dart';
import '../domain/tier.dart';
import 'game_state.dart';

/// Kebergantungan yang boleh dipalsukan dalam test.
class GameDeps {
  final Clock clock;
  final http.Client client;
  final Future<Directory> Function() docsDir;
  const GameDeps({
    required this.clock,
    required this.client,
    required this.docsDir,
  });

  static Future<Directory> defaultDocsDir() async =>
      (await getApplicationDocumentsDirectory());
}

/// Ringkasan Semalaman (dihantar sebagai event selepas init).
class OvernightSummary {
  final int offlineIncome;
  final int offlineCappedHours;
  final bool clockRolledBack;
  final List<FinishedAuctionRecord> finishedAuctions;
  final String? newsTitleKey;
  final List<String> rivalMoves; // kunci i18n + argumen diproses UI
  const OvernightSummary({
    required this.offlineIncome,
    required this.offlineCappedHours,
    required this.clockRolledBack,
    required this.finishedAuctions,
    this.newsTitleKey,
    required this.rivalMoves,
  });
}

class GameController extends AsyncNotifier<GameState> {
  GameData? _data;

  GameData get data {
    final d = _data;
    if (d == null) {
      throw StateError('GameData belum dimuatkan');
    }
    return d;
  }

  /// Akses data tanpa baling (untuk provider UI).
  GameData? get dataOrNull => _data;

  Clock get _clock =>
      ref.read(gameDepsProvider).clock;
  SaveRepository get _saves =>
      SaveRepository(ref.read(gameDepsProvider).docsDir);
  DataLoader get _loader => DataLoader(
        client: ref.read(gameDepsProvider).client,
        docsDir: ref.read(gameDepsProvider).docsDir,
      );

  final StreamController<OvernightSummary?> _summaryCtl =
      StreamController.broadcast();
  Stream<OvernightSummary?> get summaryStream => _summaryCtl.stream;

  final StreamController<String> _toastCtl = StreamController.broadcast();
  Stream<String> get toastStream => _toastCtl.stream; // kunci i18n

  @override
  Future<GameState> build() async {
    // 1) Data: cache (jika sah) → bundled.
    LoadOutcome outcome;
    try {
      outcome =
          await _loader.loadCache(appMajor: _appMajor) ??
              await _loader.loadBundled(appMajor: _appMajor);
    } on DataValidationException {
      outcome = await _loader.loadBundled(appMajor: _appMajor);
    }
    _data = outcome.data;

    // 2) Save / baru.
    final nowMinute = minutesSinceEpoch(_clock.now());
    var st = await _saves.load();
    final fresh = st == null;
    st ??= _newGame(outcome.data, nowMinute);

    // 3) Data baharu dipakai pada permulaan app seterusnya (bukan tengah sesi):
    //    dataVersionAtSave dikemas kini di sini — snapshot melindungi save lama.
    st = st.copyWith(dataVersionAtSave: outcome.data.dataVersion);

    // 4) Proses dunia (deterministik): hutang faedah, lelongan, pasar,
    //    LiveOps, kesan tamat, leaderboard mingguan.
    st = _processWorld(st, nowMinute, fresh);
    await _saves.save(st);
    _maybeBackgroundDataUpdate(); // tidak menyekat; hasil untuk start seterusnya
    return st;
  }

  int get _appMajor => 1;

  GameState _newGame(GameData d, int nowMinute) {
    final rng = SeededRng(nowMinute ^ d.balance.auctionFeePct.toInt());
    return GameState(
      dataVersionAtSave: d.dataVersion,
      tm: d.tutorial.starterGrant.tm,
      dp: 0,
      km: 0,
      rngSeed: rng.nextUint32(),
      createdAtMinute: nowMinute,
      lastSeenMinute: nowMinute,
      lastCollectMinute: nowMinute,
      lastMarketRefreshMinute: nowMinute,
      currentWeekKey: weekKey(_clock.now()),
    );
  }

  // ================================================================ WORLD
  GameState _processWorld(GameState st, int nowMinute, bool isFresh) {
    var s = st;

    // Jam diundur? (lastSeen > now) → tiada pendapatan offline sesi ini
    // (kutipan seterusnya akan 0 — log melalui summary).
    if (s.lastSeenMinute > nowMinute) {
      s = s.copyWith(lastSeenMinute: nowMinute);
    }

    // Faedah hutang mingguan.
    final wk = weekKey(_clock.now());
    if (s.debt.principal > 0 && wk > s.debt.lastInterestWeekKey) {
      final interest =
          debtWeeklyInterest(data.balance, s.debt.principal,
              cfoReductionPct: _passive(s, 'leverage_interest_reduction'));
      s = s.copyWith(
        debt: DebtState(s.debt.principal + interest, wk),
      );
    }

    // Leaderboard reset mingguan + sasaran minguan baharu.
    if (wk != s.currentWeekKey) {
      s = s.copyWith(
          weekScore: 0, currentWeekKey: wk, clearWeeklyTarget: true,
          weeklyTargetProgress: 0);
    }

    // Lelongan: proses sehingga sekarang; selesaikan yang tamat.
    s = _resolveAuctions(s, nowMinute);

    // Pasar: refresh mid-market (8 jam) — GDD E.
    s = _refreshMarketIfNeeded(s, nowMinute);

    // Kesan aktif tamat.
    s = s.copyWith(
      activeNews:
          s.activeNews.where((n) => n.endsMinute > nowMinute).toList(),
    );

    // Tamat sesi: kemas kini lastSeen.
    return s.copyWith(lastSeenMinute: nowMinute);
  }

  GameState _resolveAuctions(GameState st, int nowMinute) {
    var s = st;
    final remaining = <AuctionState>[];
    final finished = <FinishedAuctionRecord>[...s.finished];
    final lostRespawn = Map<String, int>.from(s.lostRespawn);
    final companies = [...s.companies];
    var tm = s.tm;
    var rep = s.reputation;
    var debt = s.debt;
    var weekScore = s.weekScore;
    var won = s.stats.auctionsWon;
    var lost = s.stats.auctionsLost;

    for (final a in s.auctions) {
      final simulated = simulateAuction(a, nowMinute);
      final outcome = resolveIfEnded(simulated);
      if (outcome == null) {
        remaining.add(simulated);
        continue;
      }
      if (outcome.won) {
        // Mega/Legacy: dua pusingan. Round 1 tamat → mulakan round 2.
        if (simulated.target.isMegaOrLegacy && simulated.round == 1) {
          remaining.add(createAuction(
            auctionId: '${simulated.id}_r2',
            target: simulated.target,
            ceos: data.ceos,
            nowMinute: simulated.endMinute,
            durationMinutes:
                (data.balance.auctionDurationHours * 60).round(),
            seed: simulated.seed + 1,
            round: 2,
            prevPrice: simulated.currentPrice,
          ));
          continue;
        }
        // Bayar: tunai dahulu, leverage untuk bakinya (had dari data).
        final price = outcome.finalPrice;
        final cashPart = price.clamp(0, tm);
        final leveragePart = price - cashPart;
        final maxLev = maxLeverage(data.balance, price, _netDailyIncome(s));
        final allowedLev = leveragePart.clamp(0, maxLev);
        final shortfall = leveragePart - allowedLev;
        if (shortfall > 0) {
          // Tidak mampu walaupun dengan leverage penuh → bidaan batal (kalah).
          finished.add(FinishedAuctionRecord(
              outcome.target.id, outcome.target.nameKey, false,
              'ui.app.auction.cannot_pay', price, nowMinute));
          lostRespawn[outcome.target.id] =
              nowMinute + _respawnMinutes();
          lost++;
          continue;
        }
        tm -= cashPart;
        if (allowedLev > 0) {
          debt = DebtState(debt.principal + allowedLev, debt.lastInterestWeekKey);
        }
        companies.add(OwnedCompany(outcome.target, 1, nowMinute));
        rep = (rep + 1.5).clamp(0, 100);
        weekScore += outcome.target.ntValue ~/ 1000;
        won++;
        finished.add(FinishedAuctionRecord(outcome.target.id,
            outcome.target.nameKey, true, null, price, nowMinute));
        _notifyOnce('notif.auction_won.title');
      } else {
        if (simulated.leader != null) {
          finished.add(FinishedAuctionRecord(outcome.target.id,
              outcome.target.nameKey, false, outcome.winnerCeoId,
              outcome.finalPrice, nowMinute));
          rep = (rep - 0.5).clamp(0, 100);
        }
        lostRespawn[outcome.target.id] = nowMinute + _respawnMinutes();
        if (simulated.leader != null) lost++;
      }
    }
    s = s.copyWith(
      auctions: remaining,
      finished: finished.take(12).toList(),
      lostRespawn: lostRespawn,
      companies: companies,
      tm: tm,
      reputation: rep,
      debt: debt,
      weekScore: weekScore,
      stats: s.stats.copyWith(auctionsWon: won, auctionsLost: lost),
    );
    return _checkMilestones(s);
  }

  int _respawnMinutes() {
    final red = _researchValue('respawn_reduction_hours');
    final h = (data.balance.lostTargetRespawnHours - red)
        .clamp(30.0, data.balance.lostTargetRespawnHours);
    return (h * 60).round();
  }

  GameState _refreshMarketIfNeeded(GameState st, int nowMinute) {
    final interval = AppConfig.midMarketRefreshInterval.inMinutes;
    if (nowMinute - st.lastMarketRefreshMinute < interval) return st;
    final pool = <MarketTarget>[];
    // Mid-market: 3–5 sasaran segar setiap 8 jam (deterministik).
    final rng = SeededRng(st.rngSeed ^ nowMinute ~/ interval);
    final count =
        AppConfig.midMarketMinTargets + rng.nextIntBounded(2); // 3-4
    final candidates = data.companies
        .where((c) => (c.category == 'starter' || c.category == 'midmarket'))
        .where((c) => c.tier <= st.tierIndex0 + 2) // keterlihatan ikut tier
        .where((c) => !st.companies.any((o) => o.snap.id == c.id))
        .where((c) => !st.auctions.any((a) => a.target.id == c.id))
        .where((c) =>
            (st.lostRespawn[c.id] ?? 0) <= nowMinute)
        .toList();
    final picked = <String>{};
    for (var i = 0; i < count && candidates.isNotEmpty; i++) {
      final c = candidates[rng.nextIntBounded(candidates.length)];
      if (picked.add(c.id)) {
        pool.add(MarketTarget(AuctionTargetSnapshot.fromCompany(c),
            nowMinute + interval));
      }
    }
    // Rare/Mega/Legacy: kekal pada senarai (dipaparkan ikut kategori tab);
    // lega jika tamat tempoh paparan panjang (7 hari).
    final keep = st.market
        .where((t) =>
            t.snap.category == 'rare' ||
            t.snap.category == 'mega' ||
            t.snap.category == 'legacy')
        .where((t) => t.visibleUntilMinute > nowMinute)
        .toList();
    // Tambah sasaran Rare/Mega yang belum dipaparkan (ganti lega).
    final rare = data.companies
        .where((c) =>
            c.category == 'rare' || c.category == 'mega' || c.category == 'legacy')
        .where((c) => c.tier <= st.tierIndex0 + 2)
        .where((c) => !st.companies.any((o) => o.snap.id == c.id))
        .where((c) => !pool.any((t) => t.snap.id == c.id))
        .where((c) => !keep.any((t) => t.snap.id == c.id))
        .where((c) => (st.lostRespawn[c.id] ?? 0) <= nowMinute)
        .take(3)
        .toList();
    final week = SeededRng(st.rngSeed ^ weekKey(_clock.now()));
    for (final c in rare) {
      pool.add(MarketTarget(AuctionTargetSnapshot.fromCompany(c),
          nowMinute + 7 * 24 * 60 - week.nextIntBounded(60)));
    }
    return st.copyWith(
        market: [...keep, ...pool], lastMarketRefreshMinute: nowMinute);
  }

  // =============================================================== DERIVED
  /// Pendapatan kasar sejam (operasi + syarikat + semua pengganda aktif).
  double grossIncomePerHour(GameState s, {String? sectorFilter}) {
    var opsIncome = 0.0;
    final opSectors = <String>{};
    for (final slot in s.ops) {
      final op = data.operations.firstWhere((o) => o.id == slot.opId,
          orElse: () => data.operations.first);
      if (sectorFilter != null && op.sector != sectorFilter) continue;
      opsIncome += opIncomePerHour(op, slot.level);
      opSectors.add(op.sector);
    }
    // Research: operations_income_pct (had keras dari data).
    final researchPct = _researchValue('operations_income_pct');
    // Staf passive + sinergi kecil.
    final staffPct = _passive(s, 'operations_income');
    final staffSynergy = staffSectorSynergy(
        staffFavSectors: _staffSectors(s), opSectors: opSectors);
    final companySynergy = companySynergyBonus(
        ownedSynergySectors:
            s.companies.map((c) => _synergyOf(c.snap.id)).toSet(),
        opSectors: opSectors);
    // Berita & penalti aktif (global + sektor).
    final now = _clock.now();
    var newsPct = 0.0;
    for (final n in s.activeNews) {
      newsPct += n.pct;
    }
    // Musim: pengganda daripada data (M runtime).
    final season = seasonMultiplierFor(data.seasons, weekKey(now));
    // Pengganda sektor (kiraan agregat: purata sektor operasi).
    double sectorMult = 1.0;
    if (opSectors.isNotEmpty) {
      sectorMult = opSectors
              .map((sec) => data.sector(sec).multiplier)
              .reduce((a, b) => a + b) /
          opSectors.length;
    }
    final mult = 1 +
        (researchPct + staffPct + staffSynergy + companySynergy + newsPct) /
            100.0;
    // Syarikat dimiliki.
    var companyIncome = 0.0;
    for (final c in s.companies) {
      if (sectorFilter != null && c.snap.sector != sectorFilter) continue;
      companyIncome += companyNetPerHour(
          data.balance, c.snap.grossPerHourK, c.integrationLevel);
    }
    return (opsIncome * mult * season * sectorMult) + companyIncome;
  }

  String _synergyOf(String companyId) {
    final c = data.companies.firstWhere((x) => x.id == companyId,
        orElse: () => data.companies.first);
    return c.synergySector;
  }

  Set<String> _staffSectors(GameState s) {
    // Sektor latar staf diterbitkan deterministik daripada id (D13).
    return s.staff.map((h) {
      final idx = SeededRng.hashString(h.staffId) % data.sectors.length;
      return data.sectors[idx].id;
    }).toSet();
  }

  double _researchValue(String type) {
    var v = 0.0;
    final s = state.value;
    for (final node in data.research) {
      if (node.effect.type != type) continue;
      final stage = s?.research[node.id] ?? 0;
      if (stage > 0) v += node.effect.perStageValue * stage;
    }
    final cap = data.research
        .where((n) => n.effect.type == type)
        .map((n) => n.effect.hardCapValue)
        .fold(0.0, (a, b) => a > b ? a : b);
    return v.clamp(0.0, cap).toDouble();
  }

  double _passive(GameState s, String statKey) => aggregatePassive(
      data.staffRoles,
      s.staff.map((h) => (h.roleId, h.star)),
      statKey);

  /// Pendapatan harian bersih (untuk had leverage & paparan).
  int netDailyIncomeForUi(GameState s) => _netDailyIncome(s);

  /// Nilai research teragregat untuk UI (cth. reduksi yuran).
  double researchValueForUi(String type) => _researchValue(type);

  /// Passive staf teragregat untuk UI.
  double passiveForUi(GameState s, String statKey) => _passive(s, statKey);

  int _netDailyIncome(GameState s) {
    final gross = grossIncomePerHour(s);
    final salaries = totalDailySalary(
        data.staffRoles, s.staff.map((h) => h.roleId), s.tierIndex0);
    final daily = gross *
        data.balance.calibration.activeHoursPerDay;
    return (daily - salaries).round().clamp(0, 1 << 40);
  }

  /// Pendapatan tertunggak sejak kutipan terakhir (terhad oleh had offline).
  ({int amount, int cappedHours, bool rolledBack}) pendingIncome(GameState s) {
    final nowMinute = minutesSinceEpoch(_clock.now());
    final delta = nowMinute - s.lastCollectMinute;
    if (delta <= 0) return (amount: 0, cappedHours: 0, rolledBack: delta < 0);
    final capMin = _offlineCapMinutes();
    final eff = delta.clamp(0, capMin);
    final gross = grossIncomePerHour(s);
    final amount = (gross * eff / 60.0).round();
    return (amount: amount, cappedHours: delta ~/ 60, rolledBack: false);
  }

  int _offlineCapMinutes() {
    final bonus = _researchValue('offline_cap_hours');
    final h = (data.balance.offlineCapHours + bonus).clamp(0.0, 12.0);
    return (h * 60).round();
  }

  TierUpCheck tierCheck(GameState s) => checkTierUp(
        tiers: data.tiers,
        currentTierIndex0: s.tierIndex0,
        opsSlotsFilled: s.ops.length,
        reputation: s.reputation,
        netWorth: s.tm +
            s.companies.fold(0, (a, c) => a + c.snap.ntValue),
        ownedTierIndices: s.companies.map((c) => c.snap.tier - 1).toSet(),
      );

  // ================================================================ ACTIONS
  Future<void> collect() async {
    final s = state.value;
    if (s == null) return;
    final nowMinute = minutesSinceEpoch(_clock.now());
    final pend = pendingIncome(s);
    var tm = s.tm + pend.amount;
    var weekScore = s.weekScore + pend.amount;
    var collectTotal = s.stats.collectTotal + pend.amount;

    // Gaji harian: sekali sehari semasa Collect (Peraturan C).
    final day = dayKey(_clock.now());
    if (day != s.lastSalaryDebitDayKey && s.staff.isNotEmpty) {
      final salaries = totalDailySalary(
          data.staffRoles, s.staff.map((h) => h.roleId), s.tierIndex0);
      tm = (tm - salaries).clamp(0, 1 << 40);
    }

    // Hutang: 25% daripada Collect (atas baki selepas gaji).
    if (s.debt.principal > 0 && tm > 0) {
      final repay = (tm * AppConfig.debtAutoRepayPct).round()
          .clamp(0, s.debt.principal);
      tm -= repay;
      var st2 = s.copyWith(
        debt: s.debt.withPrincipal(s.debt.principal - repay),
      );
      st2 = st2.copyWith(
        tm: tm,
        lastCollectMinute: nowMinute,
        lastSalaryDebitDayKey: day,
        weekScore: weekScore,
        stats: st2.stats.copyWith(collectTotal: collectTotal),
        dailyContractProgress:
            st2.dailyContractId == null ? 0 : st2.dailyContractProgress + pend.amount,
        weeklyTargetProgress: st2.weeklyTargetId == null
            ? 0
            : st2.weeklyTargetProgress,
      );
      _apply(
        _checkMilestones(_checkDailyContract(_checkWeekly(st2))),
      );
      await _persist();
      return;
    }
    _apply(_checkMilestones(_checkDailyContract(_checkWeekly(
      s.copyWith(
        tm: tm,
        lastCollectMinute: nowMinute,
        lastSalaryDebitDayKey: day,
        weekScore: weekScore,
        stats: s.stats.copyWith(collectTotal: collectTotal),
      ),
    ))));
    await _persist();
  }

  Future<void> upgradeOp(String opId) async {
    final s = state.value;
    if (s == null) return;
    final tier = data.tiers[s.tierIndex0];
    final idx = s.ops.indexWhere((o) => o.opId == opId);
    final op = data.operations.firstWhere((o) => o.id == opId);
    final reduction = _researchValue('upgrade_cost_reduction_pct') +
        _passive(s, 'upgrade_cost_reduction');
    if (idx >= 0) {
      final slot = s.ops[idx];
      if (slot.level >= op.maxLevel) return;
      final cost = opUpgradeCost(op, slot.level, reductionPct: reduction);
      if (s.tm < cost) {
        _toast('ui.msg.no_funds');
        return;
      }
      final ops = [...s.ops];
      ops[idx] = slot.upgraded();
      _apply(s.copyWith(ops: ops, tm: s.tm - cost));
    } else {
      if (s.ops.length >= tier.maxOperations) {
        _toast('ui.msg.tier_locked');
        return;
      }
      if (op.unlockTier > s.tierIndex0 + 1) {
        _toast('ui.msg.tier_locked');
        return;
      }
      final cost = opUpgradeCost(op, 0, reductionPct: reduction);
      if (s.tm < cost) {
        _toast('ui.msg.no_funds');
        return;
      }
      _apply(s.copyWith(ops: [...s.ops, OpSlot(opId, 1)], tm: s.tm - cost));
      _tutorialAction('tap_operation');
    }
    await _persist();
  }

  Future<void> startAuction(String companyId, {bool scripted = false}) async {
    final s = state.value;
    if (s == null) return;
    if (s.auctions.length >= 3) {
      _toast('ui.app.auction.max_concurrent');
      return;
    }
    final c = data.companies.firstWhere((x) => x.id == companyId);
    final war = _activeBiddingWar(s);
    final a = createAuction(
      auctionId: 'auc_${companyId}_${minutesSinceEpoch(_clock.now())}',
      target: AuctionTargetSnapshot.fromCompany(c),
      ceos: data.ceos,
      nowMinute: minutesSinceEpoch(_clock.now()),
      durationMinutes: (data.balance.auctionDurationHours * 60).round(),
      seed: SeededRng.hashString(companyId) ^ s.rngSeed ^ minutesSinceEpoch(_clock.now()),
      extraCompetitors: war?.$1 ?? 0,
      aggressionBoostPct: war?.$2 ?? 0,
      scripted: scripted,
      scriptedQuietMinutes: scripted
          ? data.tutorial.starterTarget.noAiBidsMinutes
          : 0,
    );
    _apply(s.copyWith(auctions: [...s.auctions, a]));
    _tutorialAction('open_market');
    await _persist();
  }

  (int, double)? _activeBiddingWar(GameState s) {
    final war = pickWeeklyBiddingWar(data.events, _clock.now());
    if (war == null) return null;
    final wkStart = weekKey(_clock.now()) * 7 * 24 * 60 + kLiveOpsAnchorMinutes();
    final startAt = wkStart + 2 * 24 * 60; // hari ke-3 minggu
    final endAt = startAt + (war.durationHours * 60).round();
    final now = minutesSinceEpoch(_clock.now());
    if (now >= startAt && now <= endAt) {
      return (war.extraCompetitorCount, war.aggressionBoostPct);
    }
    return null;
  }

  /// Bidaan pemain: yuran didebit serta-merta; leverage pilihan.
  Future<void> placeBid(String auctionId, int amount, {int leverage = 0}) async {
    final s = state.value;
    if (s == null) return;
    final idx = s.auctions.indexWhere((a) => a.id == auctionId);
    if (idx < 0) return;
    final nowMinute = minutesSinceEpoch(_clock.now());
    var a = simulateAuction(s.auctions[idx], nowMinute);
    if (amount <= a.currentPrice) return;

    // Yuran bidaan (reduksi research; hardCap data menghadkan lantai).
    final fee = auctionFee(data.balance, amount,
        reductionPct: _researchValue('auction_fee_reduction_pct'));
    // Tunai diperlukan: yuran + bahagian tunai harga (bakinya leverage).
    final maxLev = maxLeverage(data.balance, amount, _netDailyIncome(s));
    final lev = leverage.clamp(0, maxLev);
    final cashNeeded = fee + (amount - lev);
    if (s.tm < cashNeeded) {
      _toast('ui.msg.no_funds');
      return;
    }
    // Faedah leverage mingguan dijelaskan pada skrin sahkan; hutang dicatat.
    var debt = s.debt;
    if (lev > 0) {
      debt = DebtState(debt.principal + lev, debt.lastInterestWeekKey);
    }
    a = placePlayerBid(a, amount, nowMinute);
    final auctions = [...s.auctions];
    auctions[idx] = a;
    _apply(s.copyWith(
        auctions: auctions, tm: s.tm - cashNeeded, debt: debt));
    _tutorialAction('buy_first_company');
    await _persist();
  }

  Future<void> applyNegotiationClause(String auctionId, int clauseIndex) async {
    final s = state.value;
    if (s == null) return;
    final a = s.auctions.firstWhere((x) => x.id == auctionId,
        orElse: () => s.auctions.first);
    if (a.clauses == null || clauseIndex >= a.clauses!.length) return;
    final clause = a.clauses![clauseIndex];
    final price = (a.currentPrice * (1 + clause.priceAdjPct / 100.0)).round();
    final cashPart = price.clamp(0, s.tm);
    final levPart = price - cashPart;
    final maxLev = maxLeverage(data.balance, price, _netDailyIncome(s));
    final allowedLev = levPart.clamp(0, maxLev);
    if (levPart - allowedLev > 0) {
      _toast('ui.msg.no_funds');
      return;
    }
    var debt = s.debt;
    if (allowedLev > 0 && !clause.waiveLeverageInterest) {
      debt = DebtState(debt.principal + allowedLev, debt.lastInterestWeekKey);
    }
    final companies = [
      ...s.companies.where((c) => c.snap.id != a.target.id),
      OwnedCompany(a.target, clause.integrationStart, minutesSinceEpoch(_clock.now())),
    ];
    _apply(s.copyWith(
      companies: companies,
      tm: s.tm - cashPart,
      debt: debt,
      reputation: (s.reputation + clause.repDelta).clamp(0, 100).toDouble(),
      auctions: s.auctions.where((x) => x.id != auctionId).toList(),
    ));
    _checkMilestones(state.value!);
    await _persist();
  }

  Future<void> hireStaff(String staffId) async {
    final s = state.value;
    if (s == null) return;
    if (s.staff.any((h) => h.staffId == staffId)) return;
    final tier = data.tiers[s.tierIndex0];
    if (s.staff.length >= tier.maxStaff) {
      _toast('ui.msg.tier_locked');
      return;
    }
    final member = data.staffPool.firstWhere((m) => m.id == staffId);
    final role = data.staffRoles.firstWhere((r) => r.id == member.role);
    final cost = hireCost(role, member, s.tierIndex0,
        reductionPct: _passive(s, 'hire_cost_reduction'));
    if (s.tm < cost) {
      _toast('ui.msg.no_funds');
      return;
    }
    _apply(
      _checkMilestones(s.copyWith(
        tm: s.tm - cost,
        staff: [
          ...s.staff,
          HiredStaff(staffId, member.role, member.star, minutesSinceEpoch(_clock.now()))
        ],
      )),
    );
    _tutorialAction('hire_staff');
    await _persist();
  }

  Future<void> fireStaff(String staffId) async {
    final s = state.value;
    if (s == null) return;
    _apply(s.copyWith(
        staff: s.staff.where((h) => h.staffId != staffId).toList()));
    await _persist();
  }

  /// Kemahiran aktif staf (cooldown dari data).
  Future<void> useSkill(String staffId) async {
    final s = state.value;
    if (s == null) return;
    final h = s.staff.firstWhere((x) => x.staffId == staffId,
        orElse: () => s.staff.first);
    final role = data.staffRoles.firstWhere((r) => r.id == h.roleId);
    if (h.star < role.activeSkill.unlockStar) return;
    final nowMinute = minutesSinceEpoch(_clock.now());
    if ((s.skillCooldown[staffId] ?? 0) > nowMinute) return;
    final cd = role.activeSkill.cooldownHours * 60;
    switch (role.activeSkill.skillId) {
      case 'market_scan':
        // Dedah nilai tepat semua sasaran pasar selama durasi (24j + research).
        final dur = 24 * 60 + _researchValue('market_scan_duration_hours').round() * 60;
        final reveal = Map<String, int>.from(s.scanReveal);
        for (final t in s.market) {
          reveal[t.snap.id] = nowMinute + dur;
        }
        _apply(s.copyWith(scanReveal: reveal));
        break;
      case 'campaign':
        _apply(s.copyWith(
            reputation: (s.reputation + 3).clamp(0, 100).toDouble()));
        break;
      case 'overtime':
        // Bonus pendapatan segera: 2 jam pendapatan kasar operasi.
        final bonus = grossIncomePerHour(s, sectorFilter: null) * 2 * 0.10;
        _apply(s.copyWith(tm: s.tm + bonus.round()));
        break;
      case 'audit_clean':
        if (s.debt.principal > 0) {
          final cut = (s.debt.principal * 0.10).round();
          _apply(s.copyWith(
              debt: s.debt.withPrincipal(s.debt.principal - cut)));
        }
        break;
      case 'recruitment':
        _toast('role.hr.active_name'); // petunjuk; pool ikut slot
        break;
    }
    _apply(state.value!.copyWith(
        skillCooldown: {...state.value!.skillCooldown, staffId: nowMinute + cd}));
    await _persist();
  }

  Future<void> buyResearch(String nodeId) async {
    final s = state.value;
    if (s == null) return;
    final node = data.research.firstWhere((n) => n.id == nodeId);
    final stage = s.research[nodeId] ?? 0;
    if (stage >= 4) return; // 4 peringkat dari data (stage 1-4)
    if (node.unlockTier > s.tierIndex0 + 1) {
      _toast('ui.msg.tier_locked');
      return;
    }
    if (s.dp < node.costDP) {
      _toast('ui.msg.no_funds');
      return;
    }
    _apply(_checkMilestones(s.copyWith(
        dp: s.dp - node.costDP, research: {...s.research, nodeId: stage + 1})));
    await _persist();
  }

  Future<void> payDebt(int amount) async {
    final s = state.value;
    if (s == null) return;
    final pay = amount.clamp(0, s.debt.principal.clamp(0, s.tm));
    _apply(s.copyWith(
        tm: s.tm - pay,
        debt: s.debt.withPrincipal(s.debt.principal - pay)));
    await _persist();
  }

  Future<void> pitch(String angleId) async {
    final s = state.value;
    if (s == null) return;
    final nowMinute = minutesSinceEpoch(_clock.now());
    if (nowMinute - s.lastPitchMinute < kPitchCooldown.inMinutes) return;
    final angle = kPitchAngles.firstWhere((a) => a.id == angleId);
    final growthOk = _netDailyIncome(s) >=
        data.tiers[s.tierIndex0].targetDailyNetIncome;
    final safetyOk = s.debt.principal == 0;
    final storyOk = s.companies.any((c) => c.snap.category == 'legacy');
    final p = pitchProbability(
      reputation: s.reputation,
      angle: angle,
      growthConditionMet: growthOk,
      safetyConditionMet: safetyOk,
      storyConditionMet: storyOk,
    );
    final won = rollPitch(p, s.rngSeed ^ nowMinute);
    var st = s.copyWith(
        lastPitchMinute: nowMinute,
        dp: s.dp + (won ? pitchDPReward(s.tierIndex0) : 0),
        stats: s.stats.copyWith(
            pitchesWon: s.stats.pitchesWon + (won ? 1 : 0),
            pitchesLost: s.stats.pitchesLost + (won ? 0 : 1)));
    _notifyOnce('notif.investor_reply.title');
    _tutorialAction('complete_pitch');
    _apply(_checkMilestones(st));
    await _persist();
  }

  bool pitchReady(GameState s) =>
      minutesSinceEpoch(_clock.now()) - s.lastPitchMinute >=
      kPitchCooldown.inMinutes;

  int pitchSlots(GameState s) =>
      1 + (s.claimedMilestones.length ~/ 6).clamp(0, 3);

  Future<void> confirmTierUp() async {
    final s = state.value;
    if (s == null) return;
    final check = tierCheck(s);
    if (!check.canTierUp) return;
    _apply(_checkMilestones(s.copyWith(
      tierIndex0: s.tierIndex0 + 1,
      dp: s.dp + check.rewardDP,
      reputation: (s.reputation + 2).clamp(0, 100).toDouble(),
    )));
    _notifyOnce('notif.tier_up.title');
    await _persist();
  }

  Future<void> upgradeIntegration(String companyId) async {
    final s = state.value;
    if (s == null) return;
    final idx = s.companies.indexWhere((c) => c.snap.id == companyId);
    if (idx < 0) return;
    final c = s.companies[idx];
    if (c.integrationLevel >= 5) return;
    final cost = (c.snap.ntValue * 0.25 * (c.integrationLevel + 1)).round();
    if (s.tm < cost) {
      _toast('ui.msg.no_funds');
      return;
    }
    final companies = [...s.companies];
    companies[idx] = c.withIntegration(c.integrationLevel + 1);
    _apply(s.copyWith(companies: companies, tm: s.tm - cost));
    await _persist();
  }

  Future<void> buyCosmetic(String cosmeticId) async {
    final s = state.value;
    if (s == null) return;
    final c = data.cosmetics.firstWhere((x) => x.id == cosmeticId);
    if (s.km < c.priceKM) {
      _toast('ui.msg.no_funds');
      return;
    }
    _apply(_checkMilestones(s.copyWith(
        km: s.km - c.priceKM,
        claimedLiveOps: [...s.claimedLiveOps, 'cos:$cosmeticId'])));
    await _persist();
  }

  Future<void> claimMilestone(String milestoneId) async {
    final s = state.value;
    if (s == null) return;
    if (s.claimedMilestones.contains(milestoneId)) return;
    final m = data.milestones.firstWhere((x) => x.id == milestoneId);
    var st = s.copyWith(
      claimedMilestones: [...s.claimedMilestones, milestoneId],
      dp: s.dp + (m.reward.dp ?? 0),
      km: s.km + (m.reward.km ?? 0),
      tm: s.tm + (m.reward.tm ?? 0),
    );
    if (m.reward.cosmeticRef != null) {
      st = st.copyWith(claimedLiveOps: [...st.claimedLiveOps, 'cos:${m.reward.cosmeticRef}']);
    }
    _apply(st);
    await _persist();
  }

  Future<void> claimLiveOp(String key, List<Map<String, dynamic>> rewards) async {
    final s = state.value;
    if (s == null) return;
    if (s.claimedLiveOps.contains(key)) return;
    final r = applyEffects(rewards);
    var tm = s.tm, dp = s.dp, km = s.km;
    for (final c in r.currency) {
      switch (c.currency) {
        case 'tm': tm += c.amount;
        case 'dp': dp += c.amount;
        case 'km': km += c.amount;
      }
    }
    _apply(s.copyWith(
        tm: tm, dp: dp, km: km, claimedLiveOps: [...s.claimedLiveOps, key]));
    await _persist();
  }

  // ------------------------------------------------------------- settings
  Future<void> updateSettings(SettingsState settings) async {
    final s = state.value;
    if (s == null) return;
    _apply(s.copyWith(settings: settings));
    await _persist();
  }

  Future<void> setLanguage(String lang) async {
    final s = state.value;
    if (s == null) return;
    _apply(s.copyWith(settings: s.settings.copyWith(lang: lang)));
    await _persist();
  }

  Future<void> resetToBundled() async {
    await _loader.clearCache();
    _toast('ui.app.settings.reset_done');
  }

  Future<void> backgroundDataUpdateCheck() => _maybeBackgroundDataUpdate();

  Future<void> _maybeBackgroundDataUpdate() async {
    try {
      final now = _clock.now();
      // Maksimum sekali setiap 6 jam (Peraturan kemas kini data).
      // Simpan masa semak terakhir dalam save via lastMarketRefresh? Tidak —
      // guna fail timestamp berasingan untuk elak ganggu save.
      final dir = await ref.read(gameDepsProvider).docsDir();
      final ts = File('${dir.path}/last_data_check.txt');
      if (await ts.exists()) {
        final last = int.tryParse(await ts.readAsString()) ?? 0;
        if (now.millisecondsSinceEpoch ~/ 1000 - last <
            AppConfig.dataUpdateCheckInterval.inSeconds) {
          return;
        }
      }
      await ts.writeAsString(
          '${now.millisecondsSinceEpoch ~/ 1000}');
      final updated = await _loader.checkAndUpdate(appMajor: _appMajor);
      if (updated != null) {
        _toast('ui.app.settings.data_updated'); // dipakai pada start seterusnya
      }
    } catch (_) {
      // Gagal: abaikan kemas kini (cache lama dikekalkan) — Peraturan data.
    }
  }

  // ------------------------------------------------------------- tutorial
  Future<void> namingComplete(String name, String sector) async {
    final s = state.value;
    if (s == null) return;
    _apply(s.copyWith(ceoName: name, ceoSector: sector));
    _tutorialAction('enter_name_and_sector');
    await _persist();
  }

  void _tutorialAction(String action) {
    final s = state.value;
    if (s == null || s.tutorialStep > 10) return;
    final step = data.tutorial.steps
        .firstWhere((x) => x.step == s.tutorialStep, orElse: () => data.tutorial.steps.first);
    if (step.requiredAction != action) return;
    _apply(state.value!.copyWith(
        tutorialStep: s.tutorialStep + 1,
        tm: state.value!.tm + step.rewardTM));
  }

  // ----------------------------------------------------------- milestone
  GameState _checkMilestones(GameState s) {
    final completed = s.claimedMilestones.toSet();
    for (final m in data.milestones) {
      if (completed.contains(m.id)) continue;
      final ok = switch (m.goal.type) {
        'companies_owned' =>
          s.companies.where((c) => m.goal.sector == null || c.snap.sector == m.goal.sector).length >=
              m.goal.value,
        'collect_income' => s.stats.collectTotal >= m.goal.value,
        'auctions_won' => s.stats.auctionsWon >= m.goal.value,
        'tier_reached' => s.tierIndex0 + 1 >= m.goal.value,
        'staff_hired' => s.staff.length >= m.goal.value,
        'research_bought' =>
          s.research.values.fold<int>(0, (a, b) => a + b) >= m.goal.value,
        'reputation_reached' => s.reputation >= m.goal.value,
        _ => false, // jenis baharu dalam data → tidak auto (selamat)
      };
      if (ok) completed.add(m.id);
    }
    if (completed.length == s.claimedMilestones.length) return s;
    // Ganjaran milestone auto-diklaim (DP/kosmetik kecil).
    var dp = s.dp, tm = s.tm, km = s.km;
    final ops = [...s.claimedLiveOps];
    for (final id in completed.where((c) => !s.claimedMilestones.contains(c))) {
      final m = data.milestones.firstWhere((x) => x.id == id);
      dp += m.reward.dp ?? 0;
      tm += m.reward.tm ?? 0;
      km += m.reward.km ?? 0;
      if (m.reward.cosmeticRef != null) ops.add('cos:${m.reward.cosmeticRef}');
    }
    return s.copyWith(
        claimedMilestones: completed.toList(),
        dp: dp, tm: tm, km: km, claimedLiveOps: ops);
  }

  GameState _checkDailyContract(GameState s) {
    final contract = pickDailyContract(data.events, _clock.now(), s.tierIndex0);
    if (contract == null) return s;
    final day = dayKey(_clock.now());
    var st = s;
    if (st.dailyContractId != contract.id || st.dailyContractDayKey != day) {
      st = st.copyWith(
          dailyContractId: contract.id,
          dailyContractProgress: 0,
          dailyContractDayKey: day);
    }
    if (st.dailyContractProgress >= contract.goal.amount) return st;
    return st;
  }

  GameState _checkWeekly(GameState s) {
    final target = pickWeeklyTarget(data.events, _clock.now(), s.tierIndex0);
    var st = s;
    if (st.weeklyTargetId != target?.id) {
      st = st.copyWith(
          weeklyTargetId: target?.id, weeklyTargetProgress: 0);
    }
    return st;
  }

  // ================================================================ utils
  void _apply(GameState s) {
    state = AsyncData(s);
  }

  Future<void> _persist() async {
    final s = state.value;
    if (s != null) await _saves.save(s);
  }

  void _toast(String key) => _toastCtl.add(key);

  void _notifyOnce(String titleKey) {
    final s = state.value;
    if (s == null) return;
    final day = dayKey(_clock.now());
    if (s.notifCountDayKey != day) {
      _apply(s.copyWith(notifCountDayKey: day, notifCount: 0));
    }
    if ((state.value?.notifCount ?? 0) >= AppConfig.maxNotificationsPerDay) {
      return;
    }
    _apply(state.value!.copyWith(notifCount: (state.value!.notifCount) + 1));
    // Notifikasi sebenar dihantar oleh lapisan UI (plugin) — kaunter dijaga di sini.
  }

  /// Ringkasan Semalaman untuk UI (dipanggil selepas build selesai).
  OvernightSummary buildSummary(GameState s) {
    final pend = pendingIncome(s);
    final finishedToday = s.finished
        .where((f) => f.minute >= s.lastSeenMinute - 12 * 60)
        .toList();
    final news = pickMarketNews(data.events, _clock.now());
    final league = buildLeague(
      data: data.leaderboard,
      utc: _clock.now(),
      playerScore: s.weekScore,
      playerTier: s.tierIndex0 + 1,
      playerWeekGain: s.weekScore,
    );
    final moves = <String>[];
    for (final e in league.take(3)) {
      moves.add('${e.nameKey}:${e.score}');
    }
    return OvernightSummary(
      offlineIncome: pend.amount,
      offlineCappedHours: pend.cappedHours,
      clockRolledBack: pend.rolledBack,
      finishedAuctions: finishedToday,
      newsTitleKey: news?.titleKey,
      rivalMoves: moves,
    );
  }
}

int kLiveOpsAnchorMinutes() =>
    DateTime.utc(AppConfig.liveOpsAnchorYear, AppConfig.liveOpsAnchorMonth,
            AppConfig.liveOpsAnchorDay)
        .millisecondsSinceEpoch ~/
    60000;

/// Providers.
final gameDepsProvider = Provider<GameDeps>((ref) => GameDeps(
      clock: const SystemClock(),
      client: http.Client(),
      docsDir: GameDeps.defaultDocsDir,
    ));

final gameControllerProvider =
    AsyncNotifierProvider<GameController, GameState>(GameController.new);

/// Provider data (terdedah untuk UI — daripada controller).
final gameDataProvider = Provider<GameData?>((ref) {
  final st = ref.watch(gameControllerProvider);
  if (st.value == null) return null;
  return ref.read(gameControllerProvider.notifier).dataOrNull;
});
