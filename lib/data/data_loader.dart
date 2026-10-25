/// Pemuat data 3 lapisan: BUNDLED (assets) → CACHE (dokumen) → REMOTE (HTTPS).
/// Data dianggap TIDAK DIPERCAYAI: disahkan (JSON sah, fail wajib lengkap,
/// major version serasi, pariti kunci i18n, nilai dalam julat selamat) sebelum
/// digunakan. Kemas kini remote: muat turun SEMUA ke folder sementara, sahkan,
/// tukar atomik; dipakai pada permulaan app seterusnya.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../app/config.dart';
import 'models.dart';

/// Julat selamat (Peraturan keselamatan data) — diambil daripada ECONOMY_NOTES
/// repo data: costGrowth 1.0–2.0; peratus 0–1 (nisbah) / 0–100 (peratusan).
class DataValidationException implements Exception {
  final List<String> errors;
  DataValidationException(this.errors);
  @override
  String toString() => 'DataValidationException: ${errors.join('; ')}';
}

class LoadOutcome {
  final GameData data;
  final String source; // bundled | cache | remote
  const LoadOutcome(this.data, this.source);
}

class DataLoader {
  final http.Client client;
  final Future<Directory> Function() docsDir;
  final String baseUrl;
  final String dataRef;
  DataLoader({
    required this.client,
    required this.docsDir,
    this.baseUrl = AppConfig.dataBaseUrl,
    this.dataRef = AppConfig.dataRef,
  });

  // ------------------------------------------------------------- parse core
  GameData parseGameData(Map<String, String> rawFiles) {
    final json = <String, dynamic>{};
    for (final e in rawFiles.entries) {
      json[e.key] = jsonDecode(e.value);
    }
    Map<String, Map<String, String>> i18n = {};
    for (final l in AppConfig.requiredI18nLangs) {
      final m = json['i18n_$l'] as Map<String, dynamic>;
      i18n[l] = (m['strings'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as String));
    }
    return GameData(
      balance: Balance.fromJson(json['balance'] as Map<String, dynamic>),
      tiers: (json['tiers']['tiers'] as List)
          .map((e) => Tier.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      sectors: (json['sectors']['sectors'] as List)
          .map((e) => Sector.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      operations: (json['operations']['operations'] as List)
          .map((e) => Operation.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      companies: (json['companies']['companies'] as List)
          .map((e) => Company.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      ceos: (json['ai_ceos']['ceos'] as List)
          .map((e) => AiCeo.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      staffRoles: (json['staff_roles']['roles'] as List)
          .map((e) => StaffRole.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      staffPool: (json['staff_pool']['staff'] as List)
          .map((e) => StaffMember.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      research: (json['research']['nodes'] as List)
          .map((e) => ResearchNode.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      events: EventsData.fromJson(json['events'] as Map<String, dynamic>),
      seasons: (json['seasons']['seasons'] as List)
          .map((e) => Season.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      cosmetics: (json['cosmetics']['cosmetics'] as List)
          .map((e) => Cosmetic.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      milestones: (json['milestones']['milestones'] as List)
          .map((e) => Milestone.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      tutorial:
          TutorialData.fromJson(json['tutorial'] as Map<String, dynamic>),
      leaderboard:
          LeaderboardData.fromJson(json['leaderboard_bots'] as Map<String, dynamic>),
      i18n: i18n,
    );
  }

  // -------------------------------------------------------------- validation
  /// Sahkan data (dipanggil pada BUNDED, CACHE dan REMOTE sebelum dipakai).
  /// [appMajor] = major dataVersion yang disokong app ini.
  List<String> validate(GameData d, {required int appMajor}) {
    final errors = <String>[];
    final major = int.tryParse(d.dataVersion.split('.').first) ?? -1;
    if (major != appMajor) {
      errors.add('major version tidak serasi: ${d.dataVersion} vs app $appMajor');
    }
    if (d.companies.length < 200) errors.add('companies terlalu sedikit: ${d.companies.length}');
    if (d.tiers.length != 8) errors.add('tiers mesti 8: ${d.tiers.length}');
    if (d.operations.isEmpty) errors.add('operations kosong');
    if (d.ceos.isEmpty) errors.add('ai_ceos kosong');
    if (d.staffRoles.length != 5) errors.add('staff_roles mesti 5');
    for (final op in d.operations) {
      if (op.costGrowth < 1.0 || op.costGrowth > 2.0) {
        errors.add('costGrowth di luar julat selamat: ${op.id} = ${op.costGrowth}');
      }
    }
    for (final c in d.companies) {
      if (c.ntValue <= 0 || c.auctionStartPriceTM <= 0) {
        errors.add('nilai tidak sah: ${c.id}');
      }
    }
    // Pariti kunci i18n tiga bahasa.
    if (d.i18n.length == 3) {
      final en = d.i18n['en']!.keys.toSet();
      for (final l in const ['ms', 'id']) {
        final keys = d.i18n[l]!.keys.toSet();
        if (keys.length != en.length) {
          errors.add('pariti i18n $l: ${keys.length} vs en ${en.length}');
        }
      }
    } else {
      errors.add('i18n tidak lengkap: ${d.i18n.keys.toList()}');
    }
    final bal = d.balance;
    if (bal.auctionFeePct < 0 || bal.auctionFeePct > 100) {
      errors.add('auctionFeePct luar julat: ${bal.auctionFeePct}');
    }
    if (bal.leverageMaxPct < 0 || bal.leverageMaxPct > 100) {
      errors.add('leverageMaxPct luar julat');
    }
    if (bal.offlineCapHours <= 0 || bal.offlineCapHours > 24) {
      errors.add('offlineCapHours luar julat');
    }
    return errors;
  }

  // ----------------------------------------------------------------- bundled
  Future<LoadOutcome> loadBundled({int appMajor = 1}) async {
    final raw = <String, String>{};
    for (final f in AppConfig.requiredDataFiles) {
      raw[f] = await rootBundle.loadString('assets/data/$f.json');
    }
    for (final l in AppConfig.requiredI18nLangs) {
      raw['i18n_$l'] = await rootBundle.loadString('assets/data/i18n/$l.json');
    }
    final data = parseGameData(raw);
    final errors = validate(data, appMajor: appMajor);
    if (errors.isNotEmpty) throw DataValidationException(errors);
    return LoadOutcome(data, 'bundled');
  }

  // ------------------------------------------------------------------- cache
  Future<Directory> _cacheDir() async {
    final d = Directory('${(await docsDir()).path}/data_cache');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<bool> cacheExists() async {
    final f = File('${(await _cacheDir()).path}/balance.json');
    return f.exists();
  }

  Future<LoadOutcome?> loadCache({int appMajor = 1}) async {
    try {
      final dir = await _cacheDir();
      final raw = <String, String>{};
      for (final f in AppConfig.requiredDataFiles) {
        final file = File('${dir.path}/$f.json');
        if (!await file.exists()) return null;
        raw[f] = await file.readAsString();
      }
      for (final l in AppConfig.requiredI18nLangs) {
        final file = File('${dir.path}/i18n/$l.json');
        if (!await file.exists()) return null;
        raw['i18n_$l'] = await file.readAsString();
      }
      final data = parseGameData(raw);
      final errors = validate(data, appMajor: appMajor);
      if (errors.isNotEmpty) return null; // cache rosak → jatuh ke bundled
      return LoadOutcome(data, 'cache');
    } catch (_) {
      return null;
    }
  }

  /// Padam cache (Reset to bundled data).
  Future<void> clearCache() async {
    final dir = await _cacheDir();
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  // ------------------------------------------------------------------ remote
  Future<String?> _fetch(String path, {String? etag, Duration? timeout}) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{};
    if (etag != null) headers['If-None-Match'] = etag;
    final resp = await client
        .get(uri, headers: headers)
        .timeout(timeout ?? AppConfig.dataUpdateTimeout);
    if (resp.statusCode == 304) return null; // tidak berubah
    if (resp.statusCode == 404) throw http.ClientException('404 $path');
    if (resp.statusCode != 200) {
      throw http.ClientException('HTTP ${resp.statusCode} $path');
    }
    if (resp.bodyBytes.length > AppConfig.maxFileSizeBytes) {
      throw DataValidationException(['fail terlalu besar: $path']);
    }
    return resp.body;
  }

  static String etagFor(String path, String version) =>
      '"$path-$version"';

  /// Semak & muat turun kemas kini → simpan ke cache ATOMIK.
  /// Kembalikan GameData baharu jika berjaya & berbeza; null jika tiada kemas
  /// kini / gagal (cache lama dikekalkan). GUNA di latar belakang SAHAJA.
  Future<GameData?> checkAndUpdate({int appMajor = 1}) async {
    final dir = await _cacheDir();
    // 1) Dapatkan balance.json semasa untuk banding dataVersion + ETag.
    final currentBalanceFile = File('${dir.path}/balance.json');
    String? etag;
    String currentVersion = '';
    if (await currentBalanceFile.exists()) {
      try {
        final cur =
            (jsonDecode(await currentBalanceFile.readAsString())
                as Map<String, dynamic>);
        currentVersion = cur['dataVersion'] as String? ?? '';
        etag = etagFor('balance.json', currentVersion);
      } catch (_) {}
    }
    final body = await _fetch('balance.json', etag: etag);
    if (body == null) return null; // 304 — tiada kemas kini
    final newBalance = jsonDecode(body) as Map<String, dynamic>;
    final newVersion = newBalance['dataVersion'] as String? ?? '';
    if (newVersion == currentVersion) return null;

    // 2) Muat turun SEMUA fail ke folder sementara.
    final tmp = Directory('${dir.path}.tmp');
    if (await tmp.exists()) await tmp.delete(recursive: true);
    await tmp.create(recursive: true);
    try {
      final raw = <String, String>{};
      raw['balance'] = body;
      await File('${tmp.path}/balance.json').writeAsString(body);
      for (final f in AppConfig.requiredDataFiles.skip(1)) {
        final b = await _fetch('$f.json');
        raw[f] = b!;
        await File('${tmp.path}/$f.json').writeAsString(b);
      }
      final i18nDir = Directory('${tmp.path}/i18n');
      await i18nDir.create();
      for (final l in AppConfig.requiredI18nLangs) {
        final b = await _fetch('i18n/$l.json');
        raw['i18n_$l'] = b!;
        await File('${i18nDir.path}/$l.json').writeAsString(b);
      }
      // 3) Sahkan penuh sebelum tukar.
      final data = parseGameData(raw);
      final errors = validate(data, appMajor: appMajor);
      if (errors.isNotEmpty) throw DataValidationException(errors);
      // 4) Tukar atomik: alihkan lama → .old, tmp → cache, buang .old.
      final old = Directory('${dir.path}.old');
      if (await old.exists()) await old.delete(recursive: true);
      if (await dir.exists()) await dir.rename(old.path);
      await tmp.rename(dir.path);
      if (await old.exists()) await old.delete(recursive: true);
      return data;
    } catch (e) {
      // Gagal: buang tmp, kekalkan cache lama.
      if (await tmp.exists()) await tmp.delete(recursive: true);
      rethrow;
    }
  }
}
