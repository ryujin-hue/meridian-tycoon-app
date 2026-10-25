/// Enjin lelongan (Peraturan F) — DETERMINISTIK.
///
/// Semua rawak AI dikunci pada masa penciptaan lelongan (seed disimpan dalam
/// state). Lelongan diproses dalam langkah tetap 5 minit daripada
/// `processedMinute` hingga "sekarang", jadi hasil offline ≡ dimainkan langsung.
library;

import 'rng.dart';
import '../data/models.dart';

/// Saiz langkah simulasi tetap (minit) — mekanik GDD Peraturan F.
const int kAuctionStepMinutes = 5;

/// Snapshot medan penting sasaran — disimpan dalam save; jika ID tiada dalam
/// data baharu, snapshot dipakai dan app tidak crash (Peraturan keserasian save).
class AuctionTargetSnapshot {
  final String id;
  final String nameKey;
  final String sector;
  final int tier;
  final String category;
  final int ntValue;
  final double grossPerHourK;
  final int reputation;
  final int startPrice;
  final double premiumPct;
  const AuctionTargetSnapshot({
    required this.id,
    required this.nameKey,
    required this.sector,
    required this.tier,
    required this.category,
    required this.ntValue,
    required this.grossPerHourK,
    required this.reputation,
    required this.startPrice,
    required this.premiumPct,
  });

  factory AuctionTargetSnapshot.fromCompany(Company c) => AuctionTargetSnapshot(
        id: c.id,
        nameKey: c.nameKey,
        sector: c.sector,
        tier: c.tier,
        category: c.category,
        ntValue: c.ntValue,
        grossPerHourK: c.grossIncomePerHourK,
        reputation: c.reputation,
        startPrice: c.auctionStartPriceTM,
        premiumPct: c.premiumPct ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'nameKey': nameKey, 'sector': sector, 'tier': tier,
        'category': category, 'ntValue': ntValue, 'grossPerHourK': grossPerHourK,
        'reputation': reputation, 'startPrice': startPrice, 'premiumPct': premiumPct,
      };

  factory AuctionTargetSnapshot.fromJson(Map<String, dynamic> j) =>
      AuctionTargetSnapshot(
        id: j['id'] as String,
        nameKey: j['nameKey'] as String,
        sector: j['sector'] as String,
        tier: (j['tier'] as num).toInt(),
        category: j['category'] as String,
        ntValue: (j['ntValue'] as num).toInt(),
        grossPerHourK: (j['grossPerHourK'] as num).toDouble(),
        reputation: (j['reputation'] as num).toInt(),
        startPrice: (j['startPrice'] as num).toInt(),
        premiumPct: (j['premiumPct'] as num? ?? 0).toDouble(),
      );

  bool get isMegaOrLegacy => category == 'mega' || category == 'legacy';
}

/// Rancangan pembida AI — dikira SEKALI semasa lelongan dicipta.
class AiBidderPlan {
  final String ceoId;
  final double entryMinutes; // dari mula lelongan
  final double incrementPct;
  final int ceiling; // siling bidaan (TM)
  const AiBidderPlan(this.ceoId, this.entryMinutes, this.incrementPct, this.ceiling);

  Map<String, dynamic> toJson() => {
        'ceoId': ceoId, 'entryMinutes': entryMinutes,
        'incrementPct': incrementPct, 'ceiling': ceiling,
      };

  factory AiBidderPlan.fromJson(Map<String, dynamic> j) => AiBidderPlan(
        j['ceoId'] as String,
        (j['entryMinutes'] as num).toDouble(),
        (j['incrementPct'] as num).toDouble(),
        (j['ceiling'] as num).toInt(),
      );
}

/// Klausa rundingan (Mega/Legacy) — kesan angka dipaparkan sebelum sahkan.
class NegotiationClause {
  final String idKey;
  final double priceAdjPct;
  final int repDelta;
  final int integrationStart;
  final bool waiveLeverageInterest;
  const NegotiationClause(this.idKey, this.priceAdjPct, this.repDelta,
      this.integrationStart, this.waiveLeverageInterest);

  Map<String, dynamic> toJson() => {
        'idKey': idKey, 'priceAdjPct': priceAdjPct, 'repDelta': repDelta,
        'integrationStart': integrationStart,
        'waiveLeverageInterest': waiveLeverageInterest,
      };

  factory NegotiationClause.fromJson(Map<String, dynamic> j) => NegotiationClause(
        j['idKey'] as String,
        (j['priceAdjPct'] as num).toDouble(),
        (j['repDelta'] as num).toInt(),
        (j['integrationStart'] as num? ?? 1).toInt(),
        j['waiveLeverageInterest'] as bool? ?? false,
      );
}

/// Keputusan lelongan.
class AuctionOutcome {
  final String auctionId;
  final bool won; // pemain menang
  final String? winnerCeoId; // null jika tiada bidaan
  final int finalPrice;
  final AuctionTargetSnapshot target;
  const AuctionOutcome(this.auctionId, this.won, this.winnerCeoId, this.finalPrice,
      this.target);
}

/// State lelongan aktif (disimpan dalam save).
class AuctionState {
  final String id;
  final AuctionTargetSnapshot target;
  final int startMinute; // minit sejak epoch (UTC)
  final int endMinute;
  final int round; // 1 atau 2 (mega/legacy: dua pusingan)
  final int seed;
  final bool scripted; // starterTarget tutorial: tanpa bida AI
  final int scriptedQuietMinutes;
  final List<AiBidderPlan> bidders;
  final int currentPrice;
  final String? leader; // 'player' | ceoId | null
  final int processedMinute;
  final int playerBids; // bilangan bidaan pemain (yuran)
  final List<NegotiationClause>? clauses; // bila pending selepas menang

  const AuctionState({
    required this.id,
    required this.target,
    required this.startMinute,
    required this.endMinute,
    required this.round,
    required this.seed,
    required this.scripted,
    required this.scriptedQuietMinutes,
    required this.bidders,
    required this.currentPrice,
    required this.leader,
    required this.processedMinute,
    required this.playerBids,
    this.clauses,
  });

  AuctionState withClauses(List<NegotiationClause> c) => AuctionState(
        id: id, target: target, startMinute: startMinute, endMinute: endMinute,
        round: round, seed: seed, scripted: scripted,
        scriptedQuietMinutes: scriptedQuietMinutes, bidders: bidders,
        currentPrice: currentPrice, leader: leader,
        processedMinute: processedMinute, playerBids: playerBids, clauses: c,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'target': target.toJson(), 'startMinute': startMinute,
        'endMinute': endMinute, 'round': round, 'seed': seed,
        'scripted': scripted, 'scriptedQuietMinutes': scriptedQuietMinutes,
        'bidders': bidders.map((b) => b.toJson()).toList(),
        'currentPrice': currentPrice, 'leader': leader,
        'processedMinute': processedMinute, 'playerBids': playerBids,
        'clauses': clauses?.map((c) => c.toJson()).toList(),
      };

  factory AuctionState.fromJson(Map<String, dynamic> j) => AuctionState(
        id: j['id'] as String,
        target: AuctionTargetSnapshot.fromJson(j['target'] as Map<String, dynamic>),
        startMinute: (j['startMinute'] as num).toInt(),
        endMinute: (j['endMinute'] as num).toInt(),
        round: (j['round'] as num).toInt(),
        seed: (j['seed'] as num).toInt(),
        scripted: j['scripted'] as bool? ?? false,
        scriptedQuietMinutes: (j['scriptedQuietMinutes'] as num? ?? 0).toInt(),
        bidders: ((j['bidders'] as List?) ?? const [])
            .map((e) => AiBidderPlan.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        currentPrice: (j['currentPrice'] as num).toInt(),
        leader: j['leader'] as String?,
        processedMinute: (j['processedMinute'] as num).toInt(),
        playerBids: (j['playerBids'] as num? ?? 0).toInt(),
        clauses: j['clauses'] == null
            ? null
            : (j['clauses'] as List)
                .map((e) => NegotiationClause.fromJson(e as Map<String, dynamic>))
                .toList(growable: false),
      );
}

/// Cipta lelongan: siling, masa masuk & kenaikan daripada ai_ceos + seed.
/// [extraCompetitors] & [aggressionBoostPct] datang daripada Perang Bidaan.
/// [scriptedQuietMinutes] untuk starterTarget tutorial (tiada bida AI awal).
AuctionState createAuction({
  required String auctionId,
  required AuctionTargetSnapshot target,
  required List<AiCeo> ceos,
  required int nowMinute,
  required int durationMinutes,
  required int seed,
  int extraCompetitors = 0,
  double aggressionBoostPct = 0,
  int round = 1,
  int? prevPrice,
  bool scripted = false,
  int scriptedQuietMinutes = 0,
}) {
  final rng = SeededRng(seed);
  final boss = ceos.where((c) => c.auctionBoss).toList();
  final pool = <AiCeo>[];
  for (final c in ceos) {
    final fav = c.favoriteSectors.contains(target.sector);
    // Boss lelongan HANYA menyertai sasaran legacy (INTEGRATION.md repo data).
    if (c.auctionBoss && target.category != 'legacy') continue;
    // Minat ditentukan aggression (favoriteSectors menguatkan) — seeded.
    final pInterest =
        (c.aggression + (fav ? 0.30 : -0.10) + aggressionBoostPct / 100.0)
            .clamp(0.05, 0.95);
    if (rng.chance(pInterest)) pool.add(c);
  }
  // CEO tambahan (Perang Bidaan) daripada yang belum masuk pool.
  final rest = ceos.where((c) => !pool.contains(c)).toList();
  for (var i = 0; i < extraCompetitors && rest.isNotEmpty; i++) {
    pool.add(rest.removeAt(rng.nextIntBounded(rest.length)));
  }
  if (pool.isEmpty && boss.isNotEmpty && target.category == 'legacy') {
    pool.add(boss.first);
  }
  // Jaminan sekurang-kurangnya satu pesaing untuk lelongan biasa.
  if (pool.isEmpty && ceos.isNotEmpty && !scripted) {
    pool.add(ceos[rng.nextIntBounded(ceos.length)]);
  }

  final plans = <AiBidderPlan>[];
  for (final c in pool) {
    final fav = c.favoriteSectors.contains(target.sector);
    final aggression = (c.aggression + aggressionBoostPct / 100.0).clamp(0.0, 1.0);
    // Siling = NT x (1 + maxPremiumOverNT), disesuaikan profil & seed.
    var factor = 1.0 + c.maxPremiumOverNT * (0.8 + 0.4 * rng.nextDouble());
    if (fav) factor *= 1.05;
    if (target.category == 'legacy' && c.auctionBoss) factor *= 1.10;
    final ceiling = (target.ntValue * factor).round();
    // Masa masuk: entryDelay disesuaikan aggression & tierSpeed.
    var delay = c.entryDelayMinutes *
        (1 + (1 - aggression) * 0.6 * rng.nextDouble()) *
        (c.tierSpeed == 'fast' ? 0.7 : c.tierSpeed == 'slow' ? 1.4 : 1.0);
    final latest = durationMinutes * 0.7;
    if (delay > latest) delay = latest * (0.5 + 0.5 * rng.nextDouble());
    plans.add(AiBidderPlan(c.id, delay, c.bidIncrementPct, ceiling));
  }

  final startPrice = prevPrice ?? target.startPrice;
  return AuctionState(
    id: auctionId,
    target: target,
    startMinute: nowMinute,
    endMinute: nowMinute + durationMinutes,
    round: round,
    seed: seed,
    scripted: scripted,
    scriptedQuietMinutes: scriptedQuietMinutes,
    bidders: plans,
    currentPrice: startPrice,
    leader: null,
    processedMinute: nowMinute,
    playerBids: 0,
  );
}

/// Prosess simulasi langkah tetap daripada [state.processedMinute] hingga
/// [toMinute]. Tulin: memulangkan state baharu (mungkin sama).
/// Bila lelongan tamat dan pemain menang pada Mega/Legacy, klausa rundingan
/// dijana (dua pusingan sudah berlaku — round 2 ditangani oleh pemanggil).
AuctionState simulateAuction(AuctionState state, int toMinute) {
  if (toMinute <= state.processedMinute) return state;
  final capped = toMinute > state.endMinute ? state.endMinute : toMinute;
  var price = state.currentPrice;
  String? leader = state.leader;
  var t = state.processedMinute;
  final start = state.startMinute;

  while (t + kAuctionStepMinutes <= capped) {
    t += kAuctionStepMinutes;
    final elapsed = t - start;
    if (state.scripted && elapsed < state.scriptedQuietMinutes) continue;
    // Bidaan AI: pilih pembida layak dengan siling tertinggi (deterministik).
    String? bestId;
    int bestBid = 0;
    for (final p in state.bidders) {
      if (p.entryMinutes > elapsed) continue;
      if (leader == p.ceoId) continue;
      final bid = (price * (1 + p.incrementPct / 100.0)).round();
      if (bid <= p.ceiling && bid > bestBid) {
        bestBid = bid;
        bestId = p.ceoId;
      }
    }
    if (bestId != null) {
      price = bestBid;
      leader = bestId;
    }
    // Pemain TIDAK dibida automatik — bidaan pemain melalui placePlayerBid.
  }

  return AuctionState(
    id: state.id,
    target: state.target,
    startMinute: state.startMinute,
    endMinute: state.endMinute,
    round: state.round,
    seed: state.seed,
    scripted: state.scripted,
    scriptedQuietMinutes: state.scriptedQuietMinutes,
    bidders: state.bidders,
    currentPrice: price,
    leader: leader,
    processedMinute: capped,
    playerBids: state.playerBids,
    clauses: state.clauses,
  );
}

/// Bidaan pemain. Kembalikan state baharu; yuran & tunai diuruskan pemanggil.
/// Syarat: amount > currentPrice (bida mesti naik). Diproses sehingga [atMinute]
/// dahulu supaya bidaan pemain sentiasa atas keadaan terkini.
AuctionState placePlayerBid(AuctionState state, int amount, int atMinute) {
  final s = simulateAuction(state, atMinute);
  if (amount <= s.currentPrice) return s;
  return AuctionState(
    id: s.id,
    target: s.target,
    startMinute: s.startMinute,
    endMinute: s.endMinute,
    round: s.round,
    seed: s.seed,
    scripted: s.scripted,
    scriptedQuietMinutes: s.scriptedQuietMinutes,
    bidders: s.bidders,
    currentPrice: amount,
    leader: 'player',
    processedMinute: s.processedMinute,
    playerBids: s.playerBids + 1,
    clauses: s.clauses,
  );
}

/// Jana 3 klausa rundingan deterministik (Mega/Legacy selepas menang round 2).
/// Kesan angka dipaparkan pada UI sebelum pemain sahkan (DECISIONS.md D4).
List<NegotiationClause> generateClauses(int seed) {
  final rng = SeededRng(seed ^ 0xC1A0);
  final priceA = 3.0 + rng.nextDouble() * 3.0; // +3..+6%
  final repB = rng.nextIntBounded(3); // 0..2
  final priceC = -(1.0 + rng.nextDouble() * 2.0); // -3..-1%
  return [
    NegotiationClause('ui.app.clause.reputation', priceA, 3, 1, false),
    NegotiationClause('ui.app.clause.integration', 0, repB, 2, false),
    NegotiationClause('ui.app.clause.cash', priceC, -1, 1, true),
  ];
}

/// Selesaikan lelongan yang tamat → AuctionOutcome (pemenang & harga akhir).
AuctionOutcome? resolveIfEnded(AuctionState s) {
  if (s.processedMinute < s.endMinute) return null;
  final won = s.leader == 'player';
  return AuctionOutcome(s.id, won, s.leader == 'player' ? null : s.leader,
      s.currentPrice, s.target);
}
