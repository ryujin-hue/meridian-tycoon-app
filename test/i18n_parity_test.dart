/// Pariti kunci i18n 3 bahasa (data + app) — spesifikasi: test memastikan
/// pariti kunci tiga bahasa.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meridian_tycoon_app/app/i18n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> loadAppStrings(String lang) =>
      jsonDecode(File('assets/i18n_app/$lang.json').readAsStringSync())
          as Map<String, dynamic>;

  Map<String, String> loadDataStrings(String lang) =>
      ((jsonDecode(File('assets/data/i18n/$lang.json').readAsStringSync())
              as Map<String, dynamic>)['strings'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as String));

  test('data i18n: pariti penuh en == ms == id', () {
    final en = loadDataStrings('en').keys.toSet();
    final ms = loadDataStrings('ms').keys.toSet();
    final id = loadDataStrings('id').keys.toSet();
    expect(ms, en, reason: 'ms kurang: ${en.difference(ms).take(5)}');
    expect(id, en, reason: 'id kurang: ${en.difference(id).take(5)}');
  });

  test('app i18n: pariti penuh en == ms == id', () {
    final en = loadAppStrings('en').keys.toSet();
    final ms = loadAppStrings('ms').keys.toSet();
    final id = loadAppStrings('id').keys.toSet();
    expect(ms, en, reason: 'ms kurang: ${en.difference(ms).take(5)}');
    expect(id, en, reason: 'id kurang: ${en.difference(id).take(5)}');
  });

  test('tiada pelanggaran kunci: app keys bermula ui.app. atau tidak bertindih data',
      () {
    final dataKeys = loadDataStrings('en').keys.toSet();
    final appKeys = loadAppStrings('en').keys.toSet();
    final collisions = appKeys
        .where((k) => !k.startsWith('ui.app.') && dataKeys.contains(k))
        .toSet();
    expect(collisions, isEmpty, reason: collisions.take(5).join(', '));
  });

  test('I18n.merge: kunci ui.app. mengatasi; kunci data dikekalkan', () {
    final i = I18n.merge(lang: 'ms', dataStrings: loadDataStrings('ms'),
        appStrings: loadAppStrings('ms').map((k, v) => MapEntry(k, v)));
    expect(i.t('ui.btn.collect'), isNot('ui.btn.collect')); // dari data
    expect(i.t('ui.app.tab.hq'), isNot('ui.app.tab.hq')); // dari app
    expect(i.t('kunci.tiada'), 'kunci.tiada'); // fallback
    expect(i.keyCount, greaterThan(1800));
  });
}
