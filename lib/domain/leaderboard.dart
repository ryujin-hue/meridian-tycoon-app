/// Leaderboard offline: pocket league 30 pemain (pemain + 29 bot),
/// reset mingguan (Peraturan M). Skor bot = weeklyScoreBase ± variance
/// (seed minguan — deterministik). Skor pemain = pendapatan bersih dikutip
/// minggu ini + bonus menang lelongan (NT sasaran ÷ 1000).
library;

import '../data/models.dart';
import 'liveops.dart';
import 'rng.dart';

class LeagueEntry {
  final String id;
  final String nameKey; // 'player' khas atau kunci nama bot
  final int score;
  final int tier;
  final bool isPlayer;
  const LeagueEntry(this.id, this.nameKey, this.score, this.tier,
      {this.isPlayer = false});
}

/// Skor bot untuk minggu tertentu (deterministik).
int botWeeklyScore(LeaderboardBot bot, DateTime utc) {
  final rng = SeededRng(0x1337 ^ weekKey(utc) ^ SeededRng.hashString(bot.id));
  final roll = (rng.nextDouble() * 2 - 1); // [-1, 1)
  return (bot.weeklyScoreBase + bot.weeklyScoreVariance * roll).round();
}

/// Nama pengganti daripada namePool (bot "dipromosi" — deterministik).
String replacementNameKey(LeaderboardData data, DateTime utc, int slot) {
  final rng = SeededRng(0xF00D ^ weekKey(utc) ^ slot);
  return data.namePool[rng.nextIntBounded(data.namePool.length)].nameKey;
}

/// Papan penuh: 29 bot + pemain, susun menurun.
List<LeagueEntry> buildLeague({
  required LeaderboardData data,
  required DateTime utc,
  required int playerScore,
  required int playerTier,
  required int playerWeekGain,
}) {
  final entries = <LeagueEntry>[
    for (var i = 0; i < data.bots.length; i++)
      LeagueEntry(data.bots[i].id, data.bots[i].nameKey,
          botWeeklyScore(data.bots[i], utc), data.bots[i].tier),
    LeagueEntry('player', 'ui.app.league.you', playerWeekGain, playerTier,
        isPlayer: true),
  ];
  entries.sort((a, b) => b.score.compareTo(a.score));
  return entries;
}
