/// LiveOps tanpa server (Peraturan L) — dikira daripada tarikh UTC berpaut pada
/// epoch tetap dalam config. Ganjaran event hanya sampingan.
library;

import '../data/models.dart';
import 'rng.dart';

/// Anchor tetap: Isnin 2026-01-05T00:00:00Z (keputusan DECISIONS.md D10).
final DateTime kLiveOpsAnchor = DateTime.utc(2026, 1, 5);

Duration _sinceAnchor(DateTime utc) => utc.toUtc().isBefore(kLiveOpsAnchor)
    ? Duration.zero
    : utc.toUtc().difference(kLiveOpsAnchor);

int dayKey(DateTime utc) => _sinceAnchor(utc).inDays;

int weekKey(DateTime utc) => _sinceAnchor(utc).inDays ~/ 7;

int monthKey(DateTime utc) {
  final t = utc.toUtc();
  return (t.year - 2026) * 12 + (t.month - 1);
}

int minutesInWeek(DateTime utc) => _sinceAnchor(utc).inMinutes % (7 * 1440);

/// (indeks musim 0-5, minggu dalam musim 0-5, pengganda musim).
(int, int, double) seasonState(List<Season> seasons, DateTime utc) {
  if (seasons.isEmpty) return (0, 0, 1.0);
  final wk = weekKey(utc);
  final weeksPer = seasons.first.weeksPerSeason;
  final cycle = seasons.length * weeksPer;
  final idx = ((wk % cycle) + cycle) % cycle;
  return (idx ~/ weeksPer, idx % weeksPer, seasons[idx ~/ weeksPer].seasonMultiplier);
}

int tierBandFor(int tierIndex0) {
  final tier = tierIndex0 + 1;
  if (tier <= 2) return 1;
  if (tier <= 4) return 2;
  if (tier <= 6) return 3;
  return 4;
}

/// Kontrak harian untuk [utc] & tier semasa (deterministik daripada dayKey).
DailyContract? pickDailyContract(EventsData events, DateTime utc, int tierIndex0) {
  final band = tierBandFor(tierIndex0);
  final pool = events.dailyContract.where((c) => c.tierBand == band).toList();
  if (pool.isEmpty) return null;
  final rng = SeededRng(0xD11C ^ dayKey(utc) ^ tierIndex0);
  return pool[rng.nextIntBounded(pool.length)];
}

/// Sasaran minguan untuk minggu [utc].
WeeklyTarget? pickWeeklyTarget(EventsData events, DateTime utc, int tierIndex0) {
  final band = tierBandFor(tierIndex0);
  final pool = events.weeklyTarget.where((c) => c.tierBand == band).toList();
  if (pool.isEmpty) return null;
  final rng = SeededRng(0x0EE7 ^ weekKey(utc) ^ tierIndex0);
  return pool[rng.nextIntBounded(pool.length)];
}

/// Habis Stok (48 jam) untuk minggu itu — satu per minggu.
StockOutEvent? pickWeeklyStockOut(EventsData events, DateTime utc, int tierIndex0) {
  if (events.stockOut.isEmpty) return null;
  final rng = SeededRng(0x57AC ^ weekKey(utc));
  return events.stockOut[rng.nextIntBounded(events.stockOut.length)];
}

/// Perang Bidaan untuk minggu itu — satu per minggu; bermula pada jam tetap.
BiddingWarEvent? pickWeeklyBiddingWar(EventsData events, DateTime utc) {
  if (events.biddingWar.isEmpty) return null;
  final rng = SeededRng(0xB1D ^ weekKey(utc));
  return events.biddingWar[rng.nextIntBounded(events.biddingWar.length)];
}

/// Berita pasar berat-seed untuk sesi semasa.
MarketNews? pickMarketNews(EventsData events, DateTime utc, {int salt = 0}) {
  if (events.marketNews.isEmpty) return null;
  final totalWeight =
      events.marketNews.fold<int>(0, (a, n) => a + n.weight);
  final rng = SeededRng(0x3E75 ^ dayKey(utc) ^ salt);
  var roll = rng.nextIntBounded(totalWeight);
  for (final n in events.marketNews) {
    roll -= n.weight;
    if (roll < 0) return n;
  }
  return events.marketNews.last;
}

/// Mikro-event sekali-semasa.
MicroEvent? pickMicroEvent(EventsData events, DateTime utc, int salt) {
  if (events.microEvent.isEmpty) return null;
  final totalWeight =
      events.microEvent.fold<int>(0, (a, n) => a + n.weight);
  final rng = SeededRng(0x0FF1 ^ dayKey(utc) ^ salt);
  var roll = rng.nextIntBounded(totalWeight);
  for (final n in events.microEvent) {
    roll -= n.weight;
    if (roll < 0) return n;
  }
  return events.microEvent.last;
}
