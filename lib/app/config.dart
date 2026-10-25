/// Konfigurasi app. Nombor penjadualan GDD (bukan angka ekonomi data):
/// interval kemas kini 6 jam, timeout 5 saat, bayaran balik hutang 25%,
/// refresh mid-market 8 jam. Semua angka EKONOMI datang daripada GameData.
library;

class AppConfig {
  /// Sumber data remote (repo data, folder game-data/). DATA_REF boleh ditukar
  /// kepada tag (cth. 'v1.0.0') untuk kunci versi.
  static const String dataRef = String.fromEnvironment(
    'DATA_REF',
    defaultValue: 'main',
  );
  static const String dataBaseUrl =
      'https://raw.githubusercontent.com/ryujin-hue/meridian-tycoon-data/$dataRef/game-data/';

  /// Semak kemas kini maksimum sekali setiap 6 jam, latar belakang, timeout 5s.
  static const Duration dataUpdateCheckInterval = Duration(hours: 6);
  static const Duration dataUpdateTimeout = Duration(seconds: 5);

  /// Had keselamatan muat turun (data dianggap TIDAK dipercayai).
  static const int maxFileSizeBytes = 4 * 1024 * 1024; // 4 MB per fail
  static const int maxTotalBytes = 16 * 1024 * 1024; // 16 MB keseluruhan

  /// Peraturan GDD H: bayaran balik automatik 25% daripada setiap Collect.
  static const double debtAutoRepayPct = 0.25;

  /// Peraturan GDD E: mid-market 3–5 sasaran segar setiap 8 jam.
  static const Duration midMarketRefreshInterval = Duration(hours: 8);
  static const int midMarketMinTargets = 3;
  static const int midMarketMaxTargets = 5;

  /// Notifikasi: hanya keputusan, maksimum 2 sehari, pemasaran mati lalai.
  static const int maxNotificationsPerDay = 2;

  /// Anchor LiveOps (UTC) — dinyatakan juga dalam domain/liveops.dart.
  static const int liveOpsAnchorYear = 2026;
  static const int liveOpsAnchorMonth = 1;
  static const int liveOpsAnchorDay = 5;

  /// Versi app (versi APK diuruskan pubspec + CI).
  static const String appVersion = '0.1.0';

  /// Senarai fail data wajib (ikut struktur SEBENAR repo data).
  static const List<String> requiredDataFiles = [
    'balance', 'tiers', 'sectors', 'operations', 'companies', 'ai_ceos',
    'staff_roles', 'staff_pool', 'research', 'events', 'seasons', 'cosmetics',
    'milestones', 'tutorial', 'leaderboard_bots',
  ];
  static const List<String> requiredI18nLangs = ['en', 'ms', 'id'];
}
