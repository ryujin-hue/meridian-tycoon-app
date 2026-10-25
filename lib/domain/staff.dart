/// Staf (Peraturan C): lima peranan, upah dari pool ikut slot, gaji harian
/// terikat tier (didebit sekali sehari semasa Collect), kemahiran aktif dengan
/// cooldown, sinergi kecil. Staf BUKAN syarat kemenangan.
library;

import '../data/models.dart';

/// Kos ambil = hireBaseCostPerStarTM x star x hireTierScale[tierIndex]
/// (dikurangkan HR passive).
int hireCost(StaffRole role, StaffMember member, int tierIndex0,
    {double reductionPct = 0}) {
  final scale =
      role.hireTierScale[tierIndex0.clamp(0, role.hireTierScale.length - 1)];
  final raw = role.hireBaseCostPerStarTM * member.star * scale;
  return (raw * (1 - reductionPct / 100.0)).round();
}

/// Gaji harian = salaryByTier[tierIndex] (terikat tier, bukan baki tunai).
int dailySalary(StaffRole role, int tierIndex0) =>
    role.salaryByTier[tierIndex0.clamp(0, role.salaryByTier.length - 1)];

int totalDailySalary(List<StaffRole> roles, Iterable<String> hiredRoleIds,
    int tierIndex0) {
  final byId = {for (final r in roles) r.id: r};
  var sum = 0;
  for (final id in hiredRoleIds) {
    final r = byId[id];
    if (r != null) sum += dailySalary(r, tierIndex0);
  }
  return sum;
}

/// Passive staf (statKey -> % teragregat dengan hardCap): 
/// operations_income, leverage_interest_reduction, reputation_gain,
/// upgrade_cost_reduction, hire_cost_reduction.
double aggregatePassive(List<StaffRole> roles,
    Iterable<(String roleId, int star)> hired, String statKey) {
  var pct = 0.0;
  for (final (roleId, star) in hired) {
    final r = roles.firstWhere((x) => x.id == roleId,
        orElse: () => roles.first);
    if (r.passive.statKey != statKey) continue;
    pct += r.passive.perStarPct * star;
  }
  // Hard cap: nilai terbesar antara cap semua peranan yang menyumbang.
  final caps = roles
      .where((r) => r.passive.statKey == statKey)
      .map((r) => r.passive.hardCapPct);
  final cap = caps.isEmpty ? 0.0 : caps.reduce((a, b) => a > b ? a : b);
  return pct.clamp(0.0, cap).toDouble();
}

/// Sinergi kecil (DECISIONS.md D13): sektor operasi DISTINCT yang dipadani
/// oleh staf memberi +1% setiap satu (had +5%); syarikat synergySector
/// sepadan +2% setiap sektor unik (had +6%).
double staffSectorSynergy({
  required Set<String> staffFavSectors,
  required Iterable<String> opSectors,
}) {
  var pairs = 0;
  for (final s in opSectors.toSet()) {
    if (staffFavSectors.contains(s)) pairs++;
  }
  return (pairs * 1.0).clamp(0.0, 5.0).toDouble();
}

double companySynergyBonus({
  required Iterable<String> ownedSynergySectors,
  required Iterable<String> opSectors,
}) {
  var pairs = 0;
  for (final s in opSectors.toSet()) {
    if (ownedSynergySectors.contains(s)) pairs++;
  }
  return (pairs * 2.0).clamp(0.0, 6.0).toDouble();
}
