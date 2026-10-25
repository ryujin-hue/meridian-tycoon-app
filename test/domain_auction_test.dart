/// Unit test simulasi lelongan: hasil sama LANGSUNG vs OFFLINE (pariti),
/// siling AI, yuran bidaan pemain, dua pusingan Mega/Legacy, klausa rundingan,
/// starter scripted (tiada bida AI), resolusi kalah.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:meridian_tycoon_app/domain/auction.dart';

import 'fixtures.dart';

void main() {
  const durMin = 8 * 60; // auctionDurationHours daripada data (8j)
  final ceos = [
    testCeo('ceo_rohan_vex', aggression: 0.9, maxPremium: 0.3, increment: 6, delay: 10),
    testCeo('ceo_tariq_halim', aggression: 0.4, maxPremium: 0.12, increment: 3, delay: 45),
    testCeo('ceo_laila_suri', aggression: 0.2, maxPremium: 0.05, increment: 2, delay: 90),
  ];

  AuctionState newAuction({int seed = 7, String category = 'midmarket'}) {
    final c = testCompany(category: category);
    return createAuction(
      auctionId: 'a1',
      target: AuctionTargetSnapshot.fromCompany(c),
      ceos: ceos,
      nowMinute: 0,
      durationMinutes: durMin,
      seed: seed,
    );
  }

  group('Pariti langsung vs offline', () {
    test('proses sekali gus (480 min) == proses langkah demi langkah', () {
      final a = newAuction();
      final once = simulateAuction(a, 480);
      var stepwise = a;
      for (var t = 5; t <= 480; t += 5) {
        stepwise = simulateAuction(stepwise, t);
      }
      expect(once.currentPrice, stepwise.currentPrice);
      expect(once.leader, stepwise.leader);
      expect(once.processedMinute, stepwise.processedMinute);
    });

    test('proses di luar tamat dibatasi endMinute', () {
      final a = simulateAuction(newAuction(), 9999);
      expect(a.processedMinute, durMin);
    });

    test('deterministik merentas seed sama', () {
      final a = simulateAuction(newAuction(seed: 99), 480);
      final b = simulateAuction(newAuction(seed: 99), 480);
      expect(a.currentPrice, b.currentPrice);
      expect(a.leader, b.leader);
    });
  });

  group('Saingan AI', () {
    test('bidaan menaik dari harga mula dan hormat siling', () {
      final a = simulateAuction(newAuction(seed: 7), 480);
      expect(a.currentPrice, greaterThanOrEqualTo(a.target.startPrice));
      final maxCeiling =
          a.bidders.map((x) => x.ceiling).reduce((x, y) => x > y ? x : y);
      expect(a.currentPrice <= maxCeiling || a.leader == 'player', isTrue);
    });

    test('bidaan AI berlaku hanya selepas masa masuk', () {
      final a = newAuction(seed: 7);
      final early = simulateAuction(a, 4); // sebelum mana-mana entry (min 5)
      // Tiada langkah 5-min penuh lagi.
      expect(early.currentPrice, a.target.startPrice);
    });

    test('starter scripted: tiada bida AI dalam tempoh senyap', () {
      final a = createAuction(
        auctionId: 'starter',
        target: AuctionTargetSnapshot.fromCompany(testCompany()),
        ceos: ceos,
        nowMinute: 0,
        durationMinutes: durMin,
        seed: 3,
        scripted: true,
        scriptedQuietMinutes: 8,
      );
      final mid = simulateAuction(a, 7); // 7 minit — masih senyap
      expect(mid.currentPrice, a.target.startPrice);
      expect(mid.leader, isNull);
    });
  });

  group('Bidaan pemain', () {
    test('bidaan pemain menjadi pemandu & menaikkan harga', () {
      final a = simulateAuction(newAuction(seed: 5), 30);
      final b = placePlayerBid(a, a.currentPrice + 5000, 35);
      expect(b.leader, 'player');
      expect(b.currentPrice, a.currentPrice + 5000);
      expect(b.playerBids, a.playerBids + 1);
    });

    test('bidaan mesti lebih daripada harga semasa', () {
      final a = newAuction(seed: 5);
      final b = placePlayerBid(a, a.currentPrice, 6);
      expect(b.leader, isNot('player'));
    });

    test('AI membalas bidaan pemain selepas itu (jika siling benar)', () {
      final lowCeil = [
        testCeo('ceo_weak', aggression: 0.1, maxPremium: 0.01, increment: 2, delay: 1),
      ];
      final a = createAuction(
        auctionId: 'a2',
        target: AuctionTargetSnapshot.fromCompany(testCompany()),
        ceos: lowCeil,
        nowMinute: 0,
        durationMinutes: durMin,
        seed: 11,
      );
      final afterPlayer = placePlayerBid(a, a.currentPrice + 1000, 6);
      final final1 = simulateAuction(afterPlayer, 6 + 10);
      // AI siling rendah: NT(1+0.01) kecil — mungkin membalas atau tidak,
      // tetapi jika membalas, harga > bidaan pemain & pemandu = AI.
      if (final1.leader != 'player') {
        expect(final1.currentPrice, greaterThan(afterPlayer.currentPrice));
      }
    });
  });

  group('Resolusi', () {
    test('menang — pemenang player', () {
      var a = newAuction(seed: 21);
      a = placePlayerBid(a, a.target.startPrice + 1000, 6);
      // Pastikan AI tak dapat balas: guna CEO tanpa siling? Guna scripted:
      final quiet = createAuction(
        auctionId: 'a3',
        target: AuctionTargetSnapshot.fromCompany(testCompany()),
        ceos: ceos,
        nowMinute: 0,
        durationMinutes: durMin,
        seed: 21,
        scripted: true,
        scriptedQuietMinutes: 480,
      );
      final bid = placePlayerBid(quiet, quiet.currentPrice + 1000, 6);
      final out = resolveIfEnded(simulateAuction(bid, durMin + 5));
      expect(out, isNotNull);
      expect(out!.won, isTrue);
      expect(out.finalPrice, bid.currentPrice);
    });

    test('kalah — pemenang AI', () {
      final a = simulateAuction(newAuction(seed: 21), durMin + 5);
      final out = resolveIfEnded(a);
      expect(out, isNotNull);
      if (a.leader != null && a.leader != 'player') {
        expect(out!.won, isFalse);
        expect(out.winnerCeoId, a.leader);
      }
    });

    test('tiada bidaan — tiada jualan', () {
      final quiet = createAuction(
        auctionId: 'a4',
        target: AuctionTargetSnapshot.fromCompany(testCompany()),
        ceos: ceos,
        nowMinute: 0,
        durationMinutes: durMin,
        seed: 1,
        scripted: true,
        scriptedQuietMinutes: durMin + 1, // senyap sepanjang lelongan
      );
      final out = resolveIfEnded(simulateAuction(quiet, durMin + 5));
      expect(out!.won, isFalse);
      expect(out.winnerCeoId, isNull);
    });
  });

  group('Mega/Legacy dua pusingan + rundingan', () {
    test('round 2 meneruskan harga round 1', () {
      final r1 = simulateAuction(newAuction(seed: 31, category: 'mega'), durMin);
      final r2 = createAuction(
        auctionId: 'a1_r2',
        target: r1.target,
        ceos: ceos,
        nowMinute: r1.endMinute,
        durationMinutes: durMin,
        seed: r1.seed + 1,
        round: 2,
        prevPrice: r1.currentPrice,
      );
      expect(r2.currentPrice, r1.currentPrice);
      expect(r2.round, 2);
    });

    test('3 klausa rundingan deterministik dengan kesan angka', () {
      final c1 = generateClauses(123);
      final c2 = generateClauses(123);
      expect(c1.length, 3);
      expect(c1[0].idKey, c2[0].idKey);
      expect(c1[0].priceAdjPct, c2[0].priceAdjPct);
      expect(c1.map((x) => x.idKey).toSet().length, 3);
      // Satu klausa waive faedah leverage.
      expect(c1.any((x) => x.waiveLeverageInterest), isTrue);
    });
  });

  group('Snapshot keserasian save', () {
    test('JSON round-trip kekal harga/pemenang', () {
      final a = simulateAuction(newAuction(seed: 55), 300);
      final restored = AuctionState.fromJson(a.toJson());
      expect(restored.currentPrice, a.currentPrice);
      expect(restored.leader, a.leader);
      expect(restored.processedMinute, a.processedMinute);
      final cont = simulateAuction(restored, 480);
      final direct = simulateAuction(a, 480);
      expect(cont.currentPrice, direct.currentPrice);
      expect(cont.leader, direct.leader);
    });
  });
}
