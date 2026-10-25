/// Ujian save repository: penulisan atomik + sandaran, rosak → sandaran,
/// round-trip JSON, snapshot keserasian data baharu.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meridian_tycoon_app/data/save_repository.dart';
import 'package:meridian_tycoon_app/state/game_state.dart';

Directory? _tmp;

Future<Directory> docsDir() async {
  _tmp ??= await Directory.systemTemp.createTemp('mt_save_test');
  final d = Directory('${_tmp!.path}/${DateTime.now().microsecondsSinceEpoch}');
  await d.create(recursive: true);
  return d;
}

void main() {
  test('round-trip JSON GameState', () {
    final s = GameState(
      tm: 123456, dp: 10, km: 3, tierIndex0: 2, reputation: 44.5,
      ceoName: 'Ryu', ops: const [OpSlot('op_app_1', 4)],
      tutorialStep: 6,
    );
    final j = jsonEncode(s.toJson());
    final s2 = GameState.fromJson(jsonDecode(j) as Map<String, dynamic>);
    expect(s2.tm, 123456);
    expect(s2.tierIndex0, 2);
    expect(s2.ops.single.level, 4);
    expect(s2.ceoName, 'Ryu');
    expect(s2.reputation, 44.5);
  });

  test('save + load, sandaran dihasilkan pada penulisan kedua', () async {
    final dir = await docsDir();
    final repo = FileSaveRepository(() async => dir);
    await repo.save(GameState(tm: 100, ceoName: 'A'));
    await repo.save(GameState(tm: 200, ceoName: 'B'));
    final loaded = await repo.load();
    expect(loaded!.tm, 200);
    final backup = File('${dir.path}/save.backup.json');
    expect(backup.existsSync(), isTrue);
    expect(jsonDecode(backup.readAsStringSync())['ceoName'], 'A');
  });

  test('save rosak → jatuh ke sandaran', () async {
    final dir = await docsDir();
    final repo = FileSaveRepository(() async => dir);
    await repo.save(GameState(tm: 777));
    // Kerosakkan save.json.
    await File('${dir.path}/save.json').writeAsString('{rosak');
    // Tulis sandaran manual yang sah.
    await File('${dir.path}/save.backup.json')
        .writeAsString(jsonEncode(GameState(tm: 777).toJson()));
    final loaded = await repo.load();
    expect(loaded!.tm, 777);
  });

  test('import/export', () {
    final s = GameState(tm: 5, weeklyTargetProgress: 3);
    final exported = SaveRepository.export(s);
    final imported = SaveRepository.import(exported);
    expect(imported.tm, 5);
    expect(imported.weeklyTargetProgress, 3);
    expect(() => SaveRepository.import('bukan json'), throwsFormatException);
  });

  test('keserasian: save dengan dataVersion lama + snapshot ID asing tidak crash',
      () {
    final j = {
      'saveVersion': 3,
      'dataVersionAtSave': '0.9.0',
      'tm': 1000,
      'companies': [
        {
          'snap': {
            'id': 'co_tidak_wujud_lagi', // ID tiada dalam data baharu
            'nameKey': 'co.lama.name', 'sector': 'app', 'tier': 1,
            'category': 'midmarket', 'ntValue': 40000, 'grossPerHourK': 0.4,
            'reputation': 20, 'startPrice': 38000, 'premiumPct': 0,
          },
          'integrationLevel': 2, 'acquiredMinute': 100, 'weekScore': 0,
        }
      ],
    };
    final s = GameState.fromJson(j);
    // Snapshot dipakai — tiada crash; medan penting kekal.
    expect(s.companies.single.snap.id, 'co_tidak_wujud_lagi');
    expect(s.companies.single.snap.ntValue, 40000);
    expect(s.companies.single.integrationLevel, 2);
  });
}
