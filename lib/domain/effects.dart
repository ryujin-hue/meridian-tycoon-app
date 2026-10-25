/// Enjin kesan generik (Peraturan K) — membaca peta "effects"/"goal"/"reward"
/// daripada data (events, milestones, seasons) dan mengeluarkan kesan bertip.
/// Tiada logik khusus event dikodkan; jenis baharu dalam data diterima secara
/// generik dan diabaikan dengan selamat jika tidak dikenali.
library;

class CurrencyGain {
  final String currency; // tm | dp | km
  final int amount;
  const CurrencyGain(this.currency, this.amount);
}

class RepChange {
  final double delta;
  const RepChange(this.delta);
}

class TempMultiplier {
  final double pct; // +3.4 bermakna +3.4% pendapatan
  final Duration duration;
  final String sourceId;
  final String? sector; // null = global
  const TempMultiplier(this.pct, this.duration, this.sourceId, [this.sector]);
}

class IncomePenalty {
  final double pct;
  final Duration duration;
  final String sourceId;
  final String? sector;
  const IncomePenalty(this.pct, this.duration, this.sourceId, [this.sector]);
}

class UnlockSlots {
  final int count;
  final String sourceId;
  const UnlockSlots(this.count, this.sourceId);
}

class CosmeticGrant {
  final String cosmeticRef;
  const CosmeticGrant(this.cosmeticRef);
}

/// Hasil gabungan enjin kesan untuk satu senarai peta kesan.
class EffectResult {
  final List<CurrencyGain> currency;
  final List<RepChange> rep;
  final List<TempMultiplier> multipliers;
  final List<IncomePenalty> penalties;
  final List<UnlockSlots> slots;
  final List<CosmeticGrant> cosmetics;
  final List<String> unknown;
  const EffectResult({
    this.currency = const [],
    this.rep = const [],
    this.multipliers = const [],
    this.penalties = const [],
    this.slots = const [],
    this.cosmetics = const [],
    this.unknown = const [],
  });
}

/// Tafsir satu peta kesan generik daripada data.
/// Format yang disokong (daripada repo data):
///  - {"tm": 1300} / {"dp": 4} / {"km": 5} (reward)
///  - {"type": "tm"|"dp"|"km", "amount": n}
///  - {"type": "reputation_boost", "value": n}
///  - {"incomePercentPct": p, "durationHours": h} (market_news)
///  - {"incomePenaltyPct": p, "durationHours": h} (stock_out; sector di luar)
///  - {"extraCompetitorCount": n, "aggressionBoostPct": p} (bidding_war —
///    dikendalikan oleh enjin lelongan, diabaikan di sini)
///  - {"cosmeticRef": "cs_..."}
EffectResult applyEffects(Iterable<Map<String, dynamic>> maps) {
  final currency = <CurrencyGain>[];
  final rep = <RepChange>[];
  final mult = <TempMultiplier>[];
  final pen = <IncomePenalty>[];
  final slots = <UnlockSlots>[];
  final cos = <CosmeticGrant>[];
  final unknown = <String>[];

  for (final m in maps) {
    if (m.containsKey('cosmeticRef')) {
      cos.add(CosmeticGrant(m['cosmeticRef'] as String));
    }
    for (final cur in const ['tm', 'dp', 'km']) {
      if (m.containsKey(cur) && m[cur] != null) {
        currency.add(CurrencyGain(cur, (m[cur] as num).toInt()));
      }
    }
    final type = m['type'] as String?;
    switch (type) {
      case 'tm':
      case 'dp':
      case 'km':
        currency.add(CurrencyGain(type!, (m['amount'] as num? ?? 0).toInt()));
        break;
      case 'reputation_boost':
        rep.add(RepChange((m['value'] as num? ?? 0).toDouble()));
        break;
      case 'income_multiplier':
        mult.add(TempMultiplier((m['percentPct'] as num? ?? 0).toDouble(),
            Duration(minutes: (m['durationMinutes'] as num? ?? 0).toInt()),
            m['id'] as String? ?? ''));
        break;
      case 'unlock_slot':
        slots.add(UnlockSlots((m['count'] as num? ?? 1).toInt(),
            m['id'] as String? ?? ''));
        break;
      default:
        break;
    }
    if (m.containsKey('incomePercentPct')) {
      mult.add(TempMultiplier(
          (m['incomePercentPct'] as num).toDouble(),
          Duration(minutes:
              ((m['durationHours'] as num? ?? 0) * 60).round()),
          m['id'] as String? ?? 'news')); // berita pasar global
    }
    if (m.containsKey('incomePenaltyPct')) {
      pen.add(IncomePenalty(
          (m['incomePenaltyPct'] as num).toDouble(),
          Duration(minutes: ((m['durationHours'] as num? ?? 0) * 60).round()),
          m['id'] as String? ?? 'stockout',
          m['sector'] as String?));
    }
  }
  return EffectResult(
      currency: currency,
      rep: rep,
      multipliers: mult,
      penalties: pen,
      slots: slots,
      cosmetics: cos,
      unknown: unknown);
}

/// Pengganda pendapatan aktif daripada senarai multiplier/penalty pada masa t.
double activeMultiplierPct({
  required List<TempMultiplier> multipliers,
  required List<IncomePenalty> penalties,
  required DateTime now,
  required String? sector,
}) {
  var pct = 0.0;
  for (final m in multipliers) {
    if (m.sector != null && m.sector != sector) continue;
    pct += m.pct;
  }
  for (final p in penalties) {
    if (p.sector != null && p.sector != sector) continue;
    pct -= p.pct;
  }
  return pct;
}

/// Semua kesan temp ditulis sebagai "masa tamat" — penapisan tamat dibuat
/// oleh state (senarai aktif). Fungsi ini menapis senarai yang telah tamat.
List<TempMultiplier> expireMultipliers(
    List<TempMultiplier> list, DateTime activatedAt, DateTime now) {
  return list.where((m) {
    final ends = activatedAt.add(m.duration);
    return now.isBefore(ends);
  }).toList();
}
