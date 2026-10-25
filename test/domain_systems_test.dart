/// Unit test: syarat naik tier, enjin kesan, pitch, staf, LiveOps, leaderboard.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:meridian_tycoon_app/domain/tier.dart';
import 'package:meridian_tycoon_app/domain/effects.dart';
import 'package:meridian_tycoon_app/domain/pitch.dart';
import 'package:meridian_tycoon_app/domain/staff.dart';
import 'package:meridian_tycoon_app/domain/liveops.dart';
import 'package:meridian_tycoon_app/domain/leaderboard.dart';
import 'package:meridian_tycoon_app/data/models.dart';

import 'fixtures.dart';

void main() {
  group('Naik Tier (Peraturan J)', () {
    final tiers = testTiers();
    test('semua meter penuh + memiliki tier sasaran -> boleh naik', () {
      final c = checkTierUp(
        tiers: tiers,
        currentTierIndex0: 0,
        opsSlotsFilled: 3, // maxOperations t1 = 3
        reputation: 10, // ambang t2 = 10
        netWorth: 80000, // baseValueA t2 = 80000
        ownedTierIndices: {1},
      );
      expect(c.canTierUp, isTrue);
      expect(c.rewardDP, 10);
    });
    test('kapasiti tidak cukup -> gagal', () {
      final c = checkTierUp(
        tiers: tiers,
        currentTierIndex0: 0,
        opsSlotsFilled: 2,
        reputation: 10,
        netWorth: 80000,
        ownedTierIndices: {1},
      );
      expect(c.meters.firstWhere((m) => m.id == 'capacity').ok, isFalse);
      expect(c.canTierUp, isFalse);
    });
    test('tiada syarikat tier sasaran -> gagal walaupun meter penuh', () {
      final c = checkTierUp(
        tiers: tiers,
        currentTierIndex0: 0,
        opsSlotsFilled: 3,
        reputation: 50,
        netWorth: 999999,
        ownedTierIndices: {0},
      );
      expect(c.canTierUp, isFalse);
    });
    test('reputasi ikut ambang tiers data', () {
      final c = checkTierUp(
        tiers: tiers,
        currentTierIndex0: 0,
        opsSlotsFilled: 3,
        reputation: 9.9,
        netWorth: 80000,
        ownedTierIndices: {1},
      );
      expect(c.meters.firstWhere((m) => m.id == 'reputation').ok, isFalse);
    });
  });

  group('Enjin kesan generik (Peraturan K)', () {
    test('ganjaran mata wang daripada data', () {
      final r = applyEffects([
        {'tm': 1300},
        {'dp': 4},
        {'km': 5},
      ]);
      expect(r.currency.map((c) => '${c.currency}:${c.amount}').toSet(),
          {'tm:1300', 'dp:4', 'km:5'});
    });
    test('reputation_boost mikro-event', () {
      final r = applyEffects([
        {'type': 'reputation_boost', 'value': 3}
      ]);
      expect(r.rep.single.delta, 3);
    });
    test('berita pasar: pengganda sementara', () {
      final r = applyEffects([
        {'id': 'ev_news_001', 'incomePercentPct': 3.4, 'durationHours': 4}
      ]);
      final m = r.multipliers.single;
      expect(m.pct, 3.4);
      expect(m.duration, const Duration(hours: 4));
    });
    test('stock_out: penalti sektor', () {
      final r = applyEffects([
        {'id': 'ev_stockout_app_1', 'incomePenaltyPct': 35, 'durationHours': 5.4, 'sector': 'app'}
      ]);
      final p = r.penalties.single;
      expect(p.pct, 35);
      expect(p.sector, 'app');
    });
    test('cosmeticRef milestone', () {
      final r = applyEffects([
        {'cosmeticRef': 'cs_title_01'}
      ]);
      expect(r.cosmetics.single.cosmeticRef, 'cs_title_01');
    });
    test('jenis tidak dikenali tidak meletup', () {
      final r = applyEffects([
        {'type': 'baru_dalam_data_masa_depan', 'value': 9}
      ]);
      expect(r.unknown, isEmpty);
    });
    test('pengganda aktif: global + sektor sepadan sahaja', () {
      final now = DateTime.utc(2026, 10, 25);
      final mults = [
        const TempMultiplier(3.0, Duration(hours: 1), 'n1'),
        const TempMultiplier(2.0, Duration(hours: 1), 'n2', 'app'),
        const TempMultiplier(10.0, Duration(hours: 1), 'n3', 'fnb'),
      ];
      final pens = [const IncomePenalty(35, Duration(hours: 1), 's1', 'app')];
      expect(
          activeMultiplierPct(multipliers: mults, penalties: pens, now: now, sector: 'app'),
          closeTo(3.0 + 2.0 - 35.0, 0.001));
      expect(
          activeMultiplierPct(multipliers: mults, penalties: pens, now: now, sector: 'logistics'),
          closeTo(3.0, 0.001));
    });
  });

  group('Pitch pelabur (Peraturan I)', () {
    test('formula clamp(0.30 + 0.006R + modifier, 0.30, 0.90)', () {
      final p = pitchProbability(
          reputation: 50,
          angle: kPitchAngles[0],
          growthConditionMet: true,
          safetyConditionMet: false,
          storyConditionMet: false);
      expect(p, closeTo(0.30 + 0.30 + 0.05, 0.0001));
      // Bawah lantai 0.30.
      final low = pitchProbability(
          reputation: 0,
          angle: kPitchAngles[1],
          growthConditionMet: false,
          safetyConditionMet: false,
          storyConditionMet: false);
      expect(low, 0.30);
      // Atas siling 0.90.
      final high = pitchProbability(
          reputation: 100,
          angle: kPitchAngles[0],
          growthConditionMet: true,
          safetyConditionMet: true,
          storyConditionMet: true);
      expect(high, 0.90);
    });
    test('ganjaran DP ikut tier (10 x tier)', () {
      expect(pitchDPReward(0), 10);
      expect(pitchDPReward(7), 80);
    });
    test('roll deterministik', () {
      expect(rollPitch(1.0, 1), isTrue);
      expect(rollPitch(0.0, 1), isFalse);
    });
  });

  group('Staf (Peraturan C)', () {
    final roles = [
      StaffRole(
        id: 'coo',
        nameKey: 'role.coo.name',
        descKey: 'role.coo.desc',
        passive: const StaffPassive('operations_income', 2.0, 10.0, 'p'),
        activeSkill: const StaffActiveSkill('overtime', 'n', 'd', 6, 1),
        salaryByTier: const [640, 1210, 2300, 4600, 9200, 19200, 40820, 86250],
        hireBaseCostPerStarTM: 2500,
        hireTierScale: const [1, 2, 4, 8, 16, 32, 64, 128],
      ),
      StaffRole(
        id: 'hr',
        nameKey: 'role.hr.name',
        descKey: 'role.hr.desc',
        passive: const StaffPassive('hire_cost_reduction', 4.0, 20.0, 'p'),
        activeSkill: const StaffActiveSkill('recruitment', 'n', 'd', 720, 3),
        salaryByTier: const [500, 940, 1800, 3600, 7200, 15030, 31950, 67500],
        hireBaseCostPerStarTM: 2500,
        hireTierScale: const [1, 2, 4, 8, 16, 32, 64, 128],
      ),
    ];
    test('gaji harian terikat tier', () {
      expect(dailySalary(roles[0], 0), 640);
      expect(dailySalary(roles[0], 7), 86250);
    });
    test('kos ambil = 2500 x star x hireTierScale[tier]', () {
      final member = const StaffMember('st_coo_3_1', 'coo', 3, 'n', 'b');
      expect(hireCost(roles[0], member, 0), 2500 * 3 * 1);
      expect(hireCost(roles[0], member, 3), 2500 * 3 * 8);
    });
    test('agregat passive dengan hardCap', () {
      final hired = [('coo', 3), ('coo', 5)]; // 6% + 10% = 16% -> cap 10%
      expect(aggregatePassive(roles, hired, 'operations_income'), 10.0);
      final hired2 = [('coo', 1)];
      expect(aggregatePassive(roles, hired2, 'operations_income'), 2.0);
    });
    test('sinergi kecil berhad', () {
      expect(
          staffSectorSynergy(
              staffFavSectors: {'app', 'fnb'}, opSectors: ['app', 'fnb', 'app']),
          2.0);
      final capped = staffSectorSynergy(
          staffFavSectors: {'app', 'fnb', 'logistics'},
          opSectors: ['app', 'fnb', 'logistics']);
      expect(capped, lessThanOrEqualTo(5.0));
      expect(
          companySynergyBonus(
              ownedSynergySectors: {'logistics'}, opSectors: ['logistics']),
          2.0);
    });
  });

  group('LiveOps (Peraturan L)', () {
    final utc = DateTime.utc(2026, 10, 25, 12, 0);
    test('anchor ialah Isnin 2026-01-05', () {
      expect(kLiveOpsAnchor.weekday, DateTime.monday);
    });
    test('weekKey bertambah setiap 7 hari (roll Isnin)', () {
      // 2026-10-25 ialah Ahad — minggu bermula Isnin anchor.
      expect(weekKey(utc), weekKey(utc.subtract(const Duration(days: 6))));
      expect(weekKey(utc.add(const Duration(days: 1))), weekKey(utc) + 1);
    });
    test('tierBand mapping 1-4 (T1-2, T3-4, T5-6, T7-8)', () {
      expect(tierBandFor(0), 1);
      expect(tierBandFor(1), 1);
      expect(tierBandFor(2), 2);
      expect(tierBandFor(3), 2);
      expect(tierBandFor(4), 3);
      expect(tierBandFor(5), 3);
      expect(tierBandFor(6), 4);
      expect(tierBandFor(7), 4);
    });
    test('musim 6 minggu & pengganda daripada data', () {
      final seasons = [
        Season(
          id: 'sn_1',
          nameKey: 'sn.sn_1.name',
          descKey: 'sn.sn_1.desc',
          weeksPerSeason: 6,
          seasonMultiplier: 0.95,
          freeTrack: const SeasonTrack([]),
        ),
        Season(
          id: 'sn_2',
          nameKey: 'sn.sn_2.name',
          descKey: 'sn.sn_2.desc',
          weeksPerSeason: 6,
          seasonMultiplier: 1.05,
          freeTrack: const SeasonTrack([]),
        ),
      ];
      expect(seasonState(seasons, kLiveOpsAnchor).$1, 0);
      expect(seasonState(seasons, kLiveOpsAnchor.add(const Duration(days: 42))).$1,
          1);
      expect(seasonState(seasons, kLiveOpsAnchor).$3, 0.95);
    });
    test('kontrak harian deterministik untuk hari sama', () {
      final events = EventsData(
        dataVersion: '1',
        stockOut: const [],
        biddingWar: const [],
        dailyContract: [
          for (var i = 1; i <= 30; i++)
            DailyContract(
              'ev_contract_${i.toString().padLeft(2, '0')}',
              (i % 4) + 1,
              'app',
              'ev.ev_contract_$i.title',
              'ev.ev_contract_$i.desc',
              24,
              const EventGoal('collect_income', 8000),
              const EventReward(dp: 2),
            ),
        ],
        weeklyTarget: const [],
        marketNews: const [],
        microEvent: const [],
      );
      final a = pickDailyContract(events, utc, 2);
      final b = pickDailyContract(events, utc, 2);
      expect(a?.id, b?.id);
      expect(a?.tierBand, 2);
    });
  });

  group('Leaderboard pocket league (Peraturan M)', () {
    test('29 bot + pemain = 30, susun menurun, deterministik', () {
      final data = LeaderboardData(
        '1',
        30,
        [
          for (var i = 1; i <= 29; i++)
            LeaderboardBot('lb_bot_${i.toString().padLeft(2, '0')}',
                'lb.bot.${i.toString().padLeft(2, '0')}.name', (i % 8) + 1,
                40000 + i * 1000, 8900, 'sniper'),
        ],
        ['Nama A', 'Nama B'],
      );
      final utc = DateTime.utc(2026, 10, 25);
      final l1 = buildLeague(
          data: data, utc: utc, playerScore: 0, playerTier: 1, playerWeekGain: 12345);
      final l2 = buildLeague(
          data: data, utc: utc, playerScore: 0, playerTier: 1, playerWeekGain: 12345);
      expect(l1.length, 30);
      List<String> key(List<LeagueEntry> l) =>
          l.map((e) => '${e.id}:${e.score}').toList();
      expect(key(l1), key(l2));
      expect(l1.first.score, greaterThanOrEqualTo(l1.last.score));
      expect(l1.any((e) => e.isPlayer), isTrue);
      // Bot skor dalam julat base ± variance.
      for (final e in l1.where((e) => !e.isPlayer)) {
        final bot = data.bots.firstWhere((b) => b.id == e.id);
        expect(e.score,
            inInclusiveRange(bot.weeklyScoreBase - bot.weeklyScoreVariance,
                bot.weeklyScoreBase + bot.weeklyScoreVariance));
      }
    });
  });
}
