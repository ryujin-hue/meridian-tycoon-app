/// Unit test domain: formula NT (vektor eksak GDD), yuran, leverage & had,
/// faedah, bayaran balik hutang, offline (had 8 jam + jam diundur),
/// kos 1.15x, sumbangan syarikat, julat anggaran.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:meridian_tycoon_app/domain/economy.dart';
import 'package:meridian_tycoon_app/domain/rng.dart';
import 'package:meridian_tycoon_app/domain/clock.dart';

import 'fixtures.dart';

void main() {
  group('NT = A x (1 + 0.10P + 0.005R) x M — vektor eksak GDD', () {
    test('(150000, 2.4, 35, 1.10) -> 233475', () {
      expect(
          ntValue(a: 150000, p: 2.4, r: 35, m: 1.10), 233475);
    });
    test('(400000, 5.2, 62, 0.95) -> 695400', () {
      expect(
          ntValue(a: 400000, p: 5.2, r: 62, m: 0.95), 695400);
    });
    test('(3000000, 14.0, 78, 1.25) -> 10462500', () {
      expect(
          ntValue(a: 3000000, p: 14.0, r: 78, m: 1.25), 10462500);
    });
  });

  group('Harga mula & payback', () {
    final bal = testBalance();
    test('harga mula = 95% NT', () {
      expect(auctionStartPrice(bal, 233475), (233475 * 0.95).round());
    });
    test('legacy menambah premium', () {
      final p = auctionStartPrice(bal, 1000000, premiumPct: 20);
      expect(p, (1000000 * 0.95 * 1.20).round());
    });
    test('payback = harga / (0.35 x P x 1000 x 24)', () {
      final pb = paybackDays(bal, 47327, 0.33);
      expect(pb, closeTo(47327 / (0.35 * 0.33 * 1000 * 24), 0.02));
    });
  });

  group('Kos naik taraf 1.15x', () {
    test('aras 1 -> 2 = baseCost x 1.15', () {
      final op = testOp();
      expect(opUpgradeCost(op, 1), (23890 * 1.15).round());
    });
    test('aras 2 -> 3 = baseCost x 1.15^2', () {
      final op = testOp();
      expect(opUpgradeCost(op, 2), (23890 * 1.15 * 1.15).round());
    });
    test('reduksi CTO/research mengurangkan kos', () {
      final op = testOp();
      final c = opUpgradeCost(op, 1, reductionPct: 10);
      expect(c, ((23890 * 1.15).round() * 0.9).round());
    });
  });

  group('Yuran lelongan', () {
    final bal = testBalance();
    test('yuran = 2% bidaan', () {
      expect(auctionFee(bal, 100000), 2000);
    });
    test('reduksi research (hardCap data 0.8 -> min 1.2%)', () {
      // balance auctionFeePct=2.0; reduksi 40% (lebih hardCap) — reduksi
      // dilekat oleh pemanggil mengikut hardCap data; di sini uji 40% sahaja.
      expect(auctionFee(bal, 100000, reductionPct: 40), 1200);
    });
  });

  group('Leverage & had', () {
    final bal = testBalance();
    test('maks leverage = min(40% harga, 2x pendapatan harian bersih)', () {
      // Harga 1,000,000: 40% = 400,000; cap 2x 50,000 = 100,000
      expect(maxLeverage(bal, 1000000, 50000), 100000);
      // Cap lebih besar: 40% = 400,000; 2x 300,000 = 600,000
      expect(maxLeverage(bal, 1000000, 300000), 400000);
    });
    test('faedah mingguan 8% atas pokok', () {
      expect(leverageWeeklyInterest(bal, 100000), 8000);
    });
    test('CFO mengurangkan faedah', () {
      expect(leverageWeeklyInterest(bal, 100000, reductionPct: 2.5), 7800);
    });
  });

  group('Hutang', () {
    final bal = testBalance();
    test('bayaran balik automatik 25% Collect', () {
      expect(debtAutoRepayPortion(10000), 2500);
    });
    test('faedah mingguan hutang = leverageInterestWeeklyPct', () {
      expect(debtWeeklyInterest(bal, 500000), 40000);
    });
  });

  group('Offline', () {
    final bal = testBalance();
    test('had 8 jam — lonjakan ke hadapan dihadkan', () {
      final inc = offlineIncome(1000, const Duration(hours: 30),
          Duration(hours: bal.offlineCapHours.toInt()));
      expect(inc, closeTo(8000, 0.001));
    });
    test('kurang daripada had — bayar penuh', () {
      final inc = offlineIncome(1000, const Duration(hours: 3),
          Duration(hours: bal.offlineCapHours.toInt()));
      expect(inc, closeTo(3000, 0.001));
    });
    test('jam diundur -> 0 pendapatan', () {
      final inc = offlineIncome(1000, const Duration(hours: -5),
          Duration(hours: bal.offlineCapHours.toInt()));
      expect(inc, 0);
    });
    test('research menaikkan had (dari data: +1j/stage, hardCap 12j)', () {
      final cap = Duration(
          hours:
              (bal.offlineCapHours + 4).clamp(0.0, 12.0).toInt()); // hardCap data 12
      final inc = offlineIncome(1000, const Duration(hours: 30), cap);
      expect(inc, closeTo(12000, 0.001));
    });
  });

  group('Sumbangan syarikat dimiliki (integration level)', () {
    final bal = testBalance();
    test('L1 = 35% kasar', () {
      expect(companyNetPerHour(bal, 1.0, 1), closeTo(350, 0.001));
    });
    test('L5 = 35% x 1.4', () {
      expect(companyNetPerHour(bal, 1.0, 5), closeTo(490, 0.001));
    });
  });

  group('Julat anggaran nilai (±8% deterministik)', () {
    test('julat memuatkan NT dan sama setiap kali', () {
      final r1 = estimateRange('co_app_t1_01', 100000);
      final r2 = estimateRange('co_app_t1_01', 100000);
      expect(r1.low, r2.low);
      expect(r1.high, r2.high);
      expect(r1.low, lessThanOrEqualTo(100000));
      expect(r1.high, greaterThanOrEqualTo(100000));
      // Julat keseluruhan = NT ±8% (tetap, GDD E).
      expect(r1.high - r1.low, 16000);
      // Petunjuk tengah deterministik dalam julat.
      expect(r1.offsetPct, inInclusiveRange(-8, 8));
    });
    test('syarikat berbeza mendapat petunjuk tengah berbeza', () {
      var variety = <double>{};
      for (var i = 0; i < 40; i++) {
        variety.add(estimateRange('co_app_t1_${i.toString().padLeft(2, '0')}',
                100000)
            .offsetPct);
      }
      expect(variety.length, greaterThan(5));
    });
  });

  group('RNG berbenih', () {
    test('deterministik & seed berbeza berbeza', () {
      final a = SeededRng(42);
      final b = SeededRng(42);
      final seqA = List.generate(10, (_) => a.nextDouble());
      final seqB = List.generate(10, (_) => b.nextDouble());
      expect(seqA, seqB);
      final c = SeededRng(43);
      expect(List.generate(10, (_) => c.nextDouble()), isNot(seqA));
    });
    test('hashString stabil', () {
      expect(SeededRng.hashString('co_app_t1_01'),
          SeededRng.hashString('co_app_t1_01'));
    });
  });

  group('Clock', () {
    test('fromMinutesSinceEpoch bulat', () {
      final m = minutesSinceEpoch(DateTime.utc(2026, 10, 25, 12, 30));
      expect(fromMinutesSinceEpoch(m), DateTime.utc(2026, 10, 25, 12, 30));
    });
  });
}
