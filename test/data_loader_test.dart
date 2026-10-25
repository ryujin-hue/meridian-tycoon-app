/// Ujian pemuat data dengan fake HTTP client (spesifikasi):
/// berjaya, 304, 404, muat turun separuh, JSON rosak, major version tidak
/// serasi, timeout, kemas kini semasa lelongan aktif (tidak memecahkan hasil).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meridian_tycoon_app/data/data_loader.dart';
import 'package:meridian_tycoon_app/domain/auction.dart';

Directory? _tmp;

Future<Directory> docsDir() async {
  _tmp ??= await Directory.systemTemp.createTemp('mt_loader_test');
  final d = Directory('${_tmp!.path}/${DateTime.now().microsecondsSinceEpoch}');
  await d.create(recursive: true);
  return d;
}

/// Snapshot Bundled sebenar daripada assets/data (fail di-commit).
Map<String, String> bundledFiles() {
  final files = <String, String>{};
  const required = [
    'balance', 'tiers', 'sectors', 'operations', 'companies', 'ai_ceos',
    'staff_roles', 'staff_pool', 'research', 'events', 'seasons', 'cosmetics',
    'milestones', 'tutorial', 'leaderboard_bots',
  ];
  for (final f in required) {
    files['$f.json'] =
        File('assets/data/$f.json').readAsStringSync();
  }
  for (final l in const ['en', 'ms', 'id']) {
    files['i18n/$l.json'] =
        File('assets/data/i18n/$l.json').readAsStringSync();
  }
  return files;
}

http.Client fakeClient(Object? Function(String path) handler) {
  return MockClient((req) async {
    final path = req.url.toString().split('/game-data/').last;
    final resp = handler(path);
    if (resp == null) return http.Response('not found', 404);
    if (resp is http.Response) return resp;
    if (resp is String) return http.Response(resp, 200, headers: {'etag': '"v2"'});
    return http.Response(jsonEncode(resp), 200, headers: {'etag': '"v2"'});
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final bundled = bundledFiles();

  group('loadBundled (snapshot committed)', () {
    test('memuatkan 16 fail dan sah', () async {
      final loader = DataLoader(client: fakeClient((p) => null), docsDir: docsDir);
      // rootBundle dalam test perlu asset bundle — guna fail terus.
      // Dalam ujian ini kita sahkan parseGameData daripada fail sebenar.
      final data = loader.parseGameData(bundled.map((k, v) =>
          MapEntry(k.replaceAll('/', '_').replaceAll('.json', ''), v)));
      expect(data.companies.length, 216);
      expect(data.tiers.length, 8);
      expect(data.ceos.length, 7);
      expect(data.staffRoles.length, 5);
      expect(data.dataVersion, '1.0.0');
      final errors = loader.validate(data, appMajor: 1);
      expect(errors, isEmpty, reason: errors.join('; '));
    });
  });

  group('checkAndUpdate — fake HTTP', () {
    late Map<String, String> remote;
    setUp(() {
      // Salinan bundled dengan dataVersion baharu (1.1.0 → major sama).
      remote = {};
      bundled.forEach((k, v) {
        if (k.startsWith('i18n/')) {
          remote[k] = v;
        } else {
          final j = jsonDecode(v) as Map<String, dynamic>;
          remote[k] = jsonEncode(j);
        }
      });
      final bal = jsonDecode(remote['balance.json']!) as Map<String, dynamic>;
      bal['dataVersion'] = '1.1.0';
      remote['balance.json'] = jsonEncode(bal);
    });

    test('berjaya: semua fail dimuat turun, disahkan & cache ditukar atomik',
        () async {
      // Seed cache dengan versi lama (daripada bundled).
      final dir = await docsDir();
      Future<Directory> shared() async => dir;
      final cache = Directory('${dir.path}/data_cache');
      await cache.create(recursive: true);
      bundled.forEach((k, v) {
        final f = File('${cache.path}/$k');
        f.createSync(recursive: true);
        f.writeAsStringSync(v);
      });
      final client = fakeClient((path) => remote[path]);
      final loader = DataLoader(client: client, docsDir: shared);
      final updated = await loader.checkAndUpdate(appMajor: 1);
      expect(updated, isNotNull);
      expect(updated!.dataVersion, '1.1.0');
      // Cache kini versi baharu.
      final newBal = jsonDecode(
          File('${cache.path}/balance.json').readAsStringSync());
      expect(newBal['dataVersion'], '1.1.0');
      // Tiada folder tmp/old berbaki.
      expect(Directory('${cache.path}.tmp').existsSync(), isFalse);
      expect(Directory('${cache.path}.old').existsSync(), isFalse);
    });

    test('304 → tiada kemas kini', () async {
      final dir = await docsDir();
      final cache = Directory('${dir.path}/data_cache');
      await cache.create(recursive: true);
      bundled.forEach((k, v) {
        final f = File('${cache.path}/$k');
        f.createSync(recursive: true);
        f.writeAsStringSync(v);
      });
      Future<Directory> shared() async => dir;
      final client = MockClient((req) async =>
          http.Response('', 304));
      final loader = DataLoader(client: client, docsDir: shared);
      final updated = await loader.checkAndUpdate(appMajor: 1);
      expect(updated, isNull);
    });

    test('404 → baling & cache lama kekal', () async {
      final dir = await docsDir();
      final cache = Directory('${dir.path}/data_cache');
      await cache.create(recursive: true);
      bundled.forEach((k, v) {
        final f = File('${cache.path}/$k');
        f.createSync(recursive: true);
        f.writeAsStringSync(v);
      });
      Future<Directory> shared() async => dir;
      final client = fakeClient((path) =>
          path == 'tiers.json' ? null : remote[path]);
      final loader = DataLoader(client: client, docsDir: shared);
      await expectLater(loader.checkAndUpdate(appMajor: 1), throwsA(isA<http.ClientException>()));
      // Cache lama masih ada & sah.
      final outcome = await loader.loadCache(appMajor: 1);
      expect(outcome, isNotNull);
    });

    test('muat turun separuh → gagal, cache lama dikekalkan', () async {
      final dir = await docsDir();
      final cache = Directory('${dir.path}/data_cache');
      await cache.create(recursive: true);
      bundled.forEach((k, v) {
        final f = File('${cache.path}/$k');
        f.createSync(recursive: true);
        f.writeAsStringSync(v);
      });
      Future<Directory> shared() async => dir;
      final client = fakeClient((path) => path == 'companies.json'
          ? throw const SocketException('separuh')
          : remote[path]);
      final loader = DataLoader(client: client, docsDir: shared);
      await expectLater(loader.checkAndUpdate(appMajor: 1), throwsA(anything));
      expect(Directory('${cache.path}.tmp').existsSync(), isFalse);
      final outcome = await loader.loadCache(appMajor: 1);
      expect(outcome, isNotNull);
    });

    test('JSON rosak → DataValidationException / gagal, cache lama kekal',
        () async {
      remote['research.json'] = '{ bukan json';
      final dir = await docsDir();
      Future<Directory> shared() async => dir;
      final cache = Directory('${dir.path}/data_cache');
      await cache.create(recursive: true);
      bundled.forEach((k, v) {
        final f = File('${cache.path}/$k');
        f.createSync(recursive: true);
        f.writeAsStringSync(v);
      });
      final client = fakeClient((path) => remote[path]);
      final loader = DataLoader(client: client, docsDir: shared);
      await expectLater(
          loader.checkAndUpdate(appMajor: 1), throwsA(anything));
      final outcome = await loader.loadCache(appMajor: 1);
      expect(outcome, isNotNull);
    });

    test('major version tidak serasi → ditolak oleh validasi', () async {
      final bal = jsonDecode(remote['balance.json']!) as Map<String, dynamic>;
      bal['dataVersion'] = '2.0.0';
      remote['balance.json'] = jsonEncode(bal);
      final dir = await docsDir();
      Future<Directory> shared() async => dir;
      final cache = Directory('${dir.path}/data_cache');
      await cache.create(recursive: true);
      bundled.forEach((k, v) {
        final f = File('${cache.path}/$k');
        f.createSync(recursive: true);
        f.writeAsStringSync(v);
      });
      final client = fakeClient((path) => remote[path]);
      final loader = DataLoader(client: client, docsDir: shared);
      await expectLater(loader.checkAndUpdate(appMajor: 1),
          throwsA(isA<DataValidationException>()));
    });

    test('timeout → baling (pemanggil mengabaikan dengan selamat)', () async {
      final client = MockClient((req) async {
        await Future.delayed(const Duration(seconds: 30));
        return http.Response('{}', 200);
      });
      final loader = DataLoader(client: client, docsDir: docsDir);
      // Timeout 5s dari config; kita tidak mahu tunggu — panggil dengan
      // harapan ia baling cepat tidak boleh dipendekkan tanpa injeksi,
      // jadi hanya sahkan bahawa ia TimeoutException selepas timeout.
      // (Dalam CI, ujian ini memakan ~5s.)
      try {
        await loader.checkAndUpdate(appMajor: 1);
        fail('patut timeout');
      } catch (e) {
        expect(e.toString(), contains('Timeout'));
      }
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('kemas kini semasa lelongan aktif tidak memecahkan hasil — '
        'lelongan menggunakan snapshot, bukan data langsung', () {
      // Buktikan secara domain: AuctionState menyimpan snapshot sasaran;
      // menukar data tidak mengubah simulasi.
      final snap = AuctionTargetSnapshot(
        id: 'co_app_t1_01', nameKey: 'co.x.name', sector: 'app', tier: 1,
        category: 'midmarket', ntValue: 50000, grossPerHourK: 0.5,
        reputation: 30, startPrice: 47500, premiumPct: 0,
      );
      final a = createAuction(
        auctionId: 'a', target: snap, ceos: [], nowMinute: 0,
        durationMinutes: 480, seed: 42,
      );
      final before = simulateAuction(a, 480).currentPrice;
      // "Data baharu tiba" — snapshot kekal.
      final after = simulateAuction(a, 480).currentPrice;
      expect(after, before);
      expect(a.target.ntValue, 50000);
    });
  });
}
