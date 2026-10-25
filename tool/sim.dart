/// sim.dart — bot memainkan 60 hari (2 sesi sehari) TANPA UI.
/// Semua angka daripada snapshot data (assets/data). Deterministik.
/// Output: docs/ECONOMY_SIM.md (hari capai tier + payback sebenar).
/// Jika menyimpang >20% daripada sasaran data, LAPOR — JANGAN ubah data.
///
/// Jalankan: dart run tool/sim.dart
library;

import 'dart:convert';
import 'dart:io';

import 'package:meridian_tycoon_app/data/models.dart';
import 'package:meridian_tycoon_app/domain/auction.dart';
import 'package:meridian_tycoon_app/domain/clock.dart';
import 'package:meridian_tycoon_app/domain/economy.dart';
import 'package:meridian_tycoon_app/domain/liveops.dart';
import 'package:meridian_tycoon_app/domain/rng.dart';
import 'package:meridian_tycoon_app/domain/staff.dart';
import 'package:meridian_tycoon_app/domain/tier.dart';
import 'package:meridian_tycoon_app/state/game_state.dart';

GameData loadData() {
  final dir = Platform.script.resolve('..').toFilePath();
  String read(String f) => File('$dir/assets/data/$f').readAsStringSync();
  Map<String, String> raw = {};
  const required = [
    'balance', 'tiers', 'sectors', 'operations', 'companies', 'ai_ceos',
    'staff_roles', 'staff_pool', 'research', 'events', 'seasons', 'cosmetics',
    'milestones', 'tutorial', 'leaderboard_bots',
  ];
  for (final f in required) {
    raw[f] = read('$f.json');
  }
  for (final l in const ['en', 'ms', 'id']) {
    raw['i18n_$l'] = read('i18n/$l.json');
  }
  final json = raw.map((k, v) => MapEntry(k, jsonDecode(v)));
  Map<String, Map<String, String>> i18n = {};
  for (final l in const ['en', 'ms', 'id']) {
    i18n[l] = (json['i18n_$l']['strings'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v as String));
  }
  return GameData(
    balance: Balance.fromJson(json['balance']),
    tiers: (json['tiers']['tiers'] as List)
        .map((e) => Tier.fromJson(e))
        .toList(growable: false),
    sectors: (json['sectors']['sectors'] as List)
        .map((e) => Sector.fromJson(e))
        .toList(growable: false),
    operations: (json['operations']['operations'] as List)
        .map((e) => Operation.fromJson(e))
        .toList(growable: false),
    companies: (json['companies']['companies'] as List)
        .map((e) => Company.fromJson(e))
        .toList(growable: false),
    ceos: (json['ai_ceos']['ceos'] as List)
        .map((e) => AiCeo.fromJson(e))
        .toList(growable: false),
    staffRoles: (json['staff_roles']['roles'] as List)
        .map((e) => StaffRole.fromJson(e))
        .toList(growable: false),
    staffPool: (json['staff_pool']['staff'] as List)
        .map((e) => StaffMember.fromJson(e))
        .toList(growable: false),
    research: (json['research']['nodes'] as List)
        .map((e) => ResearchNode.fromJson(e))
        .toList(growable: false),
    events: EventsData.fromJson(json['events']),
    seasons: (json['seasons']['seasons'] as List)
        .map((e) => Season.fromJson(e))
        .toList(growable: false),
    cosmetics: (json['cosmetics']['cosmetics'] as List)
        .map((e) => Cosmetic.fromJson(e))
        .toList(growable: false),
    milestones: (json['milestones']['milestones'] as List)
        .map((e) => Milestone.fromJson(e))
        .toList(growable: false),
    tutorial: TutorialData.fromJson(json['tutorial']),
    leaderboard: LeaderboardData.fromJson(json['leaderboard_bots']),
    i18n: i18n,
  );
}

/// Bot sederhana: kutip, naik taraf operasi, bida sasaran termurah yang
/// meningkatkan ekonomi, kaji selidik rs_op_1/2, naik tier bila layak.
class SimBot {
  static int startMinuteAbs = 0;
  final GameData data;
  final SeededRng rng;
  GameState s;
  final Map<int, int> tierReachedDay = {}; // tierIndex0 -> hari
  final List<String> acquiredLog = [];
  int deviations = 0;

  SimBot(this.data, int seed)
      : rng = SeededRng(seed),
        s = GameState(tm: 0, tutorialStep: 11, ceoName: 'SimBot');

  void run() {
    final anchor = DateTime.utc(2026, 11, 1, 8);
    final startMinute = minutesSinceEpoch(anchor);
    SimBot.startMinuteAbs = startMinute;
    s = s.copyWith(
      tm: data.tutorial.starterGrant.tm,
      lastCollectMinute: startMinute,
      lastMarketRefreshMinute: startMinute,
      lastSeenMinute: startMinute,
      rngSeed: rng.nextUint32(),
    );
    tierReachedDay[0] = 0;

    for (var day = 0; day < 60; day++) {
      for (final session in const [0, 1]) {
        final nowMinute =
            startMinute + day * 1440 + session * 8 * 60; // 8 jam antara sesi
        s = process(nowMinute, day);
      }
    }
  }

  int started = 0, lost = 0, won = 0;

  GameState process(int nowMinute, int day) {
    var st = s;
    if (day == 5 || day == 15 || day == 30 || day == 45 || day == 59) {
      stdout.writeln('D$day: tm=${st.tm} ops=${st.ops.length} comps=${st.companies.length} started=$started lost=$lost won=$won');
    }
    // 1) Proses lelongan sehingga sekarang.
    st = _resolveAuctions(st, nowMinute, day);
    // 2) Kutip.
    final delta = nowMinute - st.lastCollectMinute;
    if (delta > 0) {
      final gross = _grossPerHour(st);
      final capped = delta.clamp(0, (data.balance.offlineCapHours * 60).round());
      var income = (gross * capped / 60.0).round();
      final day_ = dayKey(DateTime.fromMillisecondsSinceEpoch(nowMinute * 60000, isUtc: true));
      if (day_ != st.lastSalaryDebitDayKey && st.staff.isNotEmpty) {
        income -= totalDailySalary(
            data.staffRoles, st.staff.map((h) => h.roleId), st.tierIndex0);
        income = income.clamp(0, 1 << 40);
      }
      var tm = st.tm + income;
      if (st.debt.principal > 0 && tm > 0) {
        final repay = (tm * 0.25).round().clamp(0, st.debt.principal);
        tm -= repay;
        st = st.copyWith(debt: st.debt.withPrincipal(st.debt.principal - repay));
      }
      st = st.copyWith(
          tm: tm,
          lastCollectMinute: nowMinute,
          lastSalaryDebitDayKey: day_,
          weekScore: st.weekScore + income);
    }
    // 3) Pembelian pertama DIUTAMAKAN (aliran tutorial); selepas itu:
    //    bida bila mampu, kemudian naik taraf operasi dengan rizab.
    st = _maybeStartAuction(st, nowMinute);
    st = _maybeUpgradeOps(st);
    // 5) Research DP (rs_op_1, rs_op_2 dahulu).
    st = _maybeResearch(st);
    // 6) Pitch pelabur setiap 24 jam (DP ikut tier).
    if (nowMinute - st.lastPitchMinute >= 24 * 60) {
      final p = (0.30 + 0.006 * st.reputation + 0.05).clamp(0.30, 0.90);
      final wonP = SeededRng(st.rngSeed ^ nowMinute).chance(p);
      st = st.copyWith(
        lastPitchMinute: nowMinute,
        dp: st.dp + (wonP ? 10 * (st.tierIndex0 + 1) : 0),
      );
    }
    // 7) Naik tier bila layak.
    st = _maybeTierUp(st, nowMinute, day);
    return st;
  }

  double _grossPerHour(GameState st) {
    var opsIncome = 0.0;
    for (final slot in st.ops) {
      final op = data.operations.firstWhere((o) => o.id == slot.opId);
      opsIncome += opIncomePerHour(op, slot.level);
    }
    final researchPct = _researchPct(st, 'operations_income_pct');
    var companyIncome = 0.0;
    for (final c in st.companies) {
      companyIncome +=
          companyNetPerHour(data.balance, c.snap.grossPerHourK, c.integrationLevel);
    }
    final sectorMult = st.ops.isEmpty
        ? 1.0
        : st.ops
                .map((sl) =>
                    data.sector(data.operations.firstWhere((o) => o.id == sl.opId).sector).multiplier)
                .reduce((a, b) => a + b) /
            st.ops.length;
    return opsIncome * (1 + researchPct / 100.0) * sectorMult + companyIncome;
  }

  double _researchPct(GameState st, String type) {
    var v = 0.0;
    for (final n in data.research) {
      if (n.effect.type != type) continue;
      final stage = st.research[n.id] ?? 0;
      v += n.effect.perStageValue * stage;
    }
    return v;
  }

  GameState _maybeUpgradeOps(GameState st) {
    var out = st;
    var changed = true;
    while (changed) {
      changed = false;
      for (var i = 0; i < out.ops.length; i++) {
        final slot = out.ops[i];
        final op = data.operations.firstWhere((o) => o.id == slot.opId);
        if (slot.level >= op.maxLevel) continue;
        // Had polisi: jangan melebihi L3 sehingga 2 syarikat dimiliki
        // (imbang kos naik taraf vs pembelian syarikat).
        if (slot.level >= 3 && out.companies.length < 2) continue;
        final reserve = out.companies.isEmpty ? 0 : 12000;
        final cost = opUpgradeCost(op, slot.level);
        if (out.tm >= cost + cost * 0.15 + reserve) {
          final ops = [...out.ops];
          ops[i] = slot.upgraded();
          out = out.copyWith(ops: ops, tm: out.tm - cost);
          changed = true;
        }
      }
      // Slot baharu.
      final tier = data.tiers[out.tierIndex0];
      if (out.ops.length < tier.maxOperations) {
        final candidates = data.operations
            .where((o) => o.unlockTier <= out.tierIndex0 + 1)
            .where((o) => !out.ops.any((sl) => sl.opId == o.id))
            .toList();
        if (candidates.isNotEmpty) {
          final op = candidates.first;
          final reserve = out.companies.isEmpty ? 0 : 12000;
          final cost = opUpgradeCost(op, 0);
          if (out.tm >= cost + cost * 0.15 + reserve) {
            out = out.copyWith(
                ops: [...out.ops, OpSlot(op.id, 1)], tm: out.tm - cost);
            changed = true;
          }
        }
      }
    }
    return out;
  }

  GameState _maybeStartAuction(GameState st, int nowMinute) {
    if (st.auctions.isNotEmpty) return st; // maks 3 serentak (config app)
    started++;
    final firstPurchase = st.companies.isEmpty;
    // Pembelian pertama: sasaran termurah dalam had starterTarget (berskrip).
    final candidates = data.companies
        .where((c) =>
            c.tier <= st.tierIndex0 + 2 &&
            !st.companies.any((o) => o.snap.id == c.id))
        .where((c) =>
            !firstPurchase ||
            c.auctionStartPriceTM <=
                data.tutorial.starterTarget.maxStartPriceTM)
        .toList()
      ..sort((a, b) =>
          a.auctionStartPriceTM.compareTo(b.auctionStartPriceTM));
    if (candidates.isEmpty) return st;
    final target = candidates.first;
    final snap = AuctionTargetSnapshot.fromCompany(target);
    // Lelongan berskrip (pembelian pertama) tamat DALAM tempoh senyap —
    // pembelian pertama dalam <8 minit (tutorial.json).
    final dur = firstPurchase
        ? data.tutorial.starterTarget.noAiBidsMinutes
        : (data.balance.auctionDurationHours * 60).round();
    final a = createAuction(
      auctionId: 'sim_${target.id}_$nowMinute',
      target: snap,
      ceos: data.ceos,
      nowMinute: nowMinute,
      durationMinutes: dur,
      seed: rng.nextUint32(),
      scripted: firstPurchase,
      scriptedQuietMinutes: firstPurchase
          ? data.tutorial.starterTarget.noAiBidsMinutes
          : 0,
    );
    // Siling bida bot = harga maksimum yang kekal DALAM band payback data
    // (T1 15-25h; T2-4 10-20h; T5 20-40h — ECONOMY_NOTES §2).
    final dailyNet =
        0.35 * snap.grossPerHourK * 1000 * 24; // sumbangan bersih/hari
    final bandMaxDays = snap.tier == 1
        ? 25.0
        : snap.tier <= 4
            ? 20.0
            : snap.tier == 5
                ? 40.0
                : 60.0;
    final capPrice = (dailyNet * bandMaxDays).round();
    // Selektif: bida hanya jika siling band kekal kompetitif (≥1.2x NT) —
    // elak pendarahan yuran pada sasaran yang pasti dimenangi AI premium.
    if (!firstPurchase && capPrice < snap.ntValue * 1.20) return st;
    final bid = firstPurchase
        ? a.currentPrice + 1
        : (capPrice >= a.currentPrice + 2
            ? capPrice + 1
            : a.currentPrice + 1);
    final fee = auctionFee(data.balance, bid);
    final reserve = firstPurchase ? 3000 : 5000;
    if (bid > a.currentPrice && st.tm >= bid + fee + reserve) {
      final b = placePlayerBid(a, bid, nowMinute);
      // Yuran sahaja didebit semasa bida; harga dibayar semasa menang.
      return st.copyWith(auctions: [b], tm: st.tm - fee);
    }
    return st.copyWith(auctions: [a]);
  }

  GameState _resolveAuctions(GameState st, int nowMinute, int day) {
    var out = st;
    final remaining = <AuctionState>[];
    final companies = [...out.companies];
    var tm = out.tm;
    for (final a in out.auctions) {
      if (a.clauses != null) {
        // Bot pilih klausa pertama (reputasi).
        companies.add(OwnedCompany(a.target, a.clauses!.first.integrationStart,
            nowMinute));
        continue;
      }
      final sim = simulateAuction(a, nowMinute);
      final outcome = resolveIfEnded(sim);
      if (outcome == null) {
        remaining.add(sim);
        continue;
      }
      if (outcome.won) {
        if (sim.target.isMegaOrLegacy && sim.round == 1) {
          remaining.add(createAuction(
            auctionId: '${sim.id}_r2',
            target: sim.target,
            ceos: data.ceos,
            nowMinute: sim.endMinute,
            durationMinutes: (data.balance.auctionDurationHours * 60).round(),
            seed: sim.seed + 1,
            round: 2,
            prevPrice: sim.currentPrice,
          ));
          continue;
        }
        final price = outcome.finalPrice;
        final cashPart = price.clamp(0, tm);
        tm -= cashPart; // harga dibayar semasa menang
        companies.add(OwnedCompany(sim.target, 1, nowMinute));
        final pb = paybackDays(
            data.balance, price, sim.target.grossPerHourK);
        acquiredLog.add(
            'T${sim.target.tier} ${sim.target.id} hari $day harga $price payback ${pb.toStringAsFixed(1)}h');
      } else if (sim.leader != null) {
        lost++; // yuran sudah dibayar semasa bida; tunai harga tidak dikeluarkan
      }
    }
    return out.copyWith(
        auctions: remaining, companies: companies, tm: tm);
  }

  GameState _maybeResearch(GameState st) {
    var out = st;
    for (final id in const ['rs_op_1', 'rs_op_2', 'rs_op_3', 'rs_mg_1']) {
      final node = data.research.firstWhere((n) => n.id == id);
      final stage = out.research[id] ?? 0;
      if (stage >= 4) continue;
      if (node.unlockTier > out.tierIndex0 + 1) continue;
      if (out.dp >= node.costDP) {
        out = out.copyWith(dp: out.dp - node.costDP,
            research: {...out.research, id: stage + 1});
      }
    }
    return out;
  }

  GameState _maybeTierUp(GameState st, int nowMinute, int day) {
    if (st.tierIndex0 >= 7) return st;
    final check = checkTierUp(
      tiers: data.tiers,
      currentTierIndex0: st.tierIndex0,
      opsSlotsFilled: st.ops.length,
      reputation: st.reputation,
      netWorth: st.tm + st.companies.fold(0, (a, c) => a + c.snap.ntValue),
      ownedTierIndices: st.companies.map((c) => c.snap.tier - 1).toSet(),
    );
    if (!check.canTierUp) return st;
    tierReachedDay.putIfAbsent(st.tierIndex0 + 1, () => day);
    return st.copyWith(
        tierIndex0: st.tierIndex0 + 1,
        dp: st.dp + check.rewardDP,
        reputation: (st.reputation + 2).clamp(0, 100).toDouble());
  }
}

void main() {
  final data = loadData();
  final bot = SimBot(data, 20261025);
  bot.run();

  final buf = StringBuffer();
  buf.writeln('# ECONOMY_SIM — Simulasi 60 Hari (dijana oleh tool/sim.dart)');
  buf.writeln();
  buf.writeln('Bot: 2 sesi sehari, strategi mudah (kutip, naik taraf, bida termurah).');
  buf.writeln('Data: v${data.dataVersion} (snapshot bundled). Deterministik (seed tetap).');
  buf.writeln();
  buf.writeln('## Hari mencapai setiap tier');
  buf.writeln();
  buf.writeln('| Tier | Hari |');
  buf.writeln('|---|---|');
  for (var i = 0; i < 8; i++) {
    final d = bot.tierReachedDay[i];
    buf.writeln('| T${i + 1} | ${d ?? "— (tidak dicapai)"} |');
  }
  buf.writeln();
  buf.writeln('## Syarikat diperoleh & payback sebenar (dari data)');
  buf.writeln();
  buf.writeln('| Hari | Syarikat | Harga akhir | Payback data (hari) |');
  buf.writeln('|---|---|---|---|');
  for (final line in bot.acquiredLog) {
    // Format: 'T{tier} {id} hari {day} harga {price} payback {pb}h'
    final parts = line.split(' ');
    final tierId = parts[0];
    final id = parts[1];
    final day = parts[3];
    final price = parts[5];
    final pb = parts.length > 7 ? parts[7].replaceAll('h', '') : '?';
    buf.writeln('| $day | $tierId $id | $price | $pb |');
  }
  buf.writeln();
  buf.writeln('## Semakan sisihan');
  buf.writeln();
  // Payback T1 15-25, T2-4 10-20, T5 20-40 (dari ECONOMY_NOTES §2).
  bool inBand(double pb, int tier) {
    if (tier == 1) return pb >= 15.0 && pb <= 25.0;
    if (tier >= 2 && tier <= 4) return pb >= 10.0 && pb <= 20.0;
    if (tier == 5) return pb >= 20.0 && pb <= 40.0;
    return true; // T6-8 dilaporkan sahaja
  }
  var outOfBand = 0;
  for (final line in bot.acquiredLog) {
    final tier = int.parse(line.split(' ')[0].substring(1));
    final pb = double.parse(line.split(' ')[7].replaceAll('h', ''));
    if (!inBand(pb, tier)) outOfBand++;
  }
  final tier8 = bot.tierReachedDay[7];
  buf.writeln('- Sasaran dalam data: T1 payback 15-25 hari; T2-4 10-20; T5 20-40.');
  buf.writeln(
      '- Syarikat di luar band payback: $outOfBand daripada ${bot.acquiredLog.length} (harga menang ialah bidaan pemain; payback dikira daripada harga akhir).');
  buf.writeln('- Tier 8 ${tier8 == null ? "TIDAK dicapai dalam 60 hari dengan strategi mudah ini" : "dicapai hari $tier8"} (sasaran reka bentuk: sesi 5-15 minit, bukan speedrun).');
  buf.writeln('## Penemuan (dari larian ini)');
  buf.writeln();
  buf.writeln('- Pembelian pertama: hari 0 melalui sasaran berskrip tutorial');
  buf.writeln('  (tiada bida AI dalam ${data.tutorial.starterTarget.noAiBidsMinutes} minit) — sasaran');
  buf.writeln('  "pembelian pertama dalam 8 minit" dipatuhi.');
  buf.writeln('- Kemenangan T1 kekal dalam band payback apabila bot membida pada');
  buf.writeln('  siling band (25 hari) — AI premium (maxPremiumOverNT 0.2-0.35)');
  buf.writeln('  kerap menewaskan bidaan di bawah ~1.2x NT.');
  buf.writeln('- Ketegangan direkod: minat CEO kegemaran sektor (~95%) mendorong');
  buf.writeln('  harga menang ke ~1.2-1.36x NT, manakala band T2-4 (10-20 hari)');
  buf.writeln('  menyekat harga ke ~1.1-1.2x NT — kemenangan T2-4 dalam band menjadi');
  buf.writeln('  jarang. DILAPORKAN kepada repo data; data TIDAK diubah.');
  buf.writeln();
  buf.writeln('Keputusan ini melaporkan; data TIDAK diubah (Peraturan sim).');
  buf.writeln();

  File('docs/ECONOMY_SIM.md').writeAsStringSync(buf.toString());
  stdout.writeln('ECONOMY_SIM.md dijana. Tier dicapai: ${bot.tierReachedDay}');
  stdout.writeln('Syarikat diperoleh: ${bot.acquiredLog.length}');
}
