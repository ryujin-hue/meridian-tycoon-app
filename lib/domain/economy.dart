/// Ekonomi teras — SEMUA angka datang dari data (balance.json / tiers.json /
/// operations.json / companies.json). Tiada nombor ekonomi dikodkan keras di sini;
/// konstanta formula (0.10/0.005) ialah bentuk GDD yang direkodkan dalam
/// docs/ECONOMY_NOTES.md repo data.
library;

import 'dart:math' as math;

import '../data/models.dart';
import 'rng.dart';

/// NT = A x (1 + 0.10 x P + 0.005 x R) x M
/// [p] = pendapatan kasar sejam dalam ribu TM; [r] = reputasi 0-100;
/// [a] = asas nilai tier; [m] = pengganda sektor (x musim semasa runtime).
int ntValue({required int a, required double p, required double r, required double m}) {
  final v = a * (1 + 0.10 * p + 0.005 * r) * m;
  return v.round();
}

/// Harga mula lelongan = auctionStartPctOfNT% daripada NT (legacy + premiumPct).
int auctionStartPrice(Balance bal, int nt, {double premiumPct = 0}) {
  final v = nt * (bal.auctionStartPctOfNT / 100.0) * (1 + premiumPct / 100.0);
  return v.round();
}

/// Payback (hari) = harga mula / (0.35 x P x 1000 x 24).
/// 0.35 ialah purchasedCompanyNetContributionPct daripada balance.json.
double paybackDays(Balance bal, int startPrice, double grossPerHourK) {
  final denom = (bal.purchasedCompanyNetContributionPct / 100.0) *
      grossPerHourK *
      1000 *
      24;
  if (denom <= 0) return double.infinity;
  return startPrice / denom;
}

/// Kos naik taraf operasi dari aras [currentLevel] ke [currentLevel]+1:
/// baseCost x costGrowth^currentLevel (GDD: kos = baseCost x costGrowth^(level-1)).
int opUpgradeCost(Operation op, int currentLevel, {double reductionPct = 0}) {
  final cost = (op.baseCost * math.pow(op.costGrowth, currentLevel)).round();
  return (cost * (1 - reductionPct / 100.0)).round();
}

/// Pendapatan operasi aras [level] = baseIncomePerHour x incomeGrowthPerLevel^(level-1).
double opIncomePerHour(Operation op, int level) {
  final inc = op.baseIncomePerHour * math.pow(op.incomeGrowthPerLevel, level - 1);
  return inc;
}

/// Pendapatan offline: kadar x min(elapsed, cap). Tidak menghukum ketidakhadiran.
double offlineIncome(double incomePerHour, Duration elapsed, Duration cap) {
  if (elapsed <= Duration.zero) return 0;
  final eff = elapsed < cap ? elapsed : cap;
  return incomePerHour * eff.inMicroseconds / 3600000000.0;
}

/// Sumbangan bersih syarikat dimiliki (Peraturan G):
/// grossPerHourK x 1000 x contributionPct% x (1 + 0.10 x (integrationLevel - 1)).
double companyNetPerHour(Balance bal, double grossPerHourK, int integrationLevel) {
  final base = grossPerHourK * 1000 * (bal.purchasedCompanyNetContributionPct / 100.0);
  return base * (1 + 0.10 * (integrationLevel.clamp(1, 5) - 1));
}

/// Yuran lelongan untuk satu bidaan: feePct daripada jumlah bidaan,
/// dikurangkan reductionPct (research/CFO), dilantai 0 (hardCap data menghadkan).
int auctionFee(Balance bal, int bidAmount, {double reductionPct = 0}) {
  final pct = (bal.auctionFeePct * (1 - reductionPct / 100.0));
  return (bidAmount * pct / 100.0).round();
}

/// Leverage (Peraturan F): maks = min(leverageMaxPct% x harga,
/// leverageCapDailyNetMultiplier x pendapatan harian bersih).
int maxLeverage(Balance bal, int price, int netDailyIncome) {
  final byPct = (price * bal.leverageMaxPct / 100.0).floor();
  final byCap = (bal.leverageCapDailyNetMultiplier * netDailyIncome).floor();
  return math.max(0, math.min(byPct, byCap));
}

/// Faedah leverage mingguan atas baki (CFO mengurangkan).
int leverageWeeklyInterest(Balance bal, int principal, {double reductionPct = 0}) {
  final pct = bal.leverageInterestWeeklyPct * (1 - reductionPct / 100.0);
  return (principal * pct / 100.0).round();
}

/// Hutang: faedah mingguan atas baki pokok; bayaran balik automatik 25%
/// daripada setiap Collect (GDD Peraturan H; 25% ialah peraturan mekanik, bukan data).
int debtAutoRepayPortion(int collectAmount, {double pct = 0.25}) =>
    (collectAmount * pct).round();

int debtWeeklyInterest(Balance bal, int principal, {double cfoReductionPct = 0}) =>
    leverageWeeklyInterest(bal, principal, reductionPct: cfoReductionPct);

/// Julat anggaran nilai sasaran (Peraturan E): JULAT ±8% di sekitar NT
/// (tetap mengikut GDD). offsetPct (deterministik daripada id) ialah petunjuk
/// "anggaran tengah" yang dipaparkan pada kad — stabil merentas render.
({int low, int high, double offsetPct}) estimateRange(String companyId, int nt) {
  final low = (nt * 0.92).round();
  final high = (nt * 1.08).round();
  final rng = SeededRng(SeededRng.hashString(companyId) ^ 0x45D1);
  final offset = (rng.nextDouble() * 16.0) - 8.0; // [-8, +8)
  return (low: low, high: high, offsetPct: offset);
}

/// Pengganda sektor x musim semasa runtime (M): musim dipilih daripada
/// indeks minggu global (dikira oleh liveops.dart daripada anchor tetap).
double seasonMultiplierFor(List<Season> seasons, int globalWeekIndex) {
  if (seasons.isEmpty) return 1.0;
  return seasonMultiplierAt(seasons, globalWeekIndex).$2;
}

(double, double) seasonMultiplierAt(List<Season> seasons, int globalWeekIndex) {
  if (seasons.isEmpty) return (0, 1.0);
  var i = globalWeekIndex;
  final weeksPer = seasons.first.weeksPerSeason;
  final cycle = seasons.length * weeksPer;
  while (i < 0) {
    i += cycle;
  }
  final seasonIdx = (i ~/ weeksPer) % seasons.length;
  return (seasonIdx.toDouble(), seasons[seasonIdx].seasonMultiplier);
}
