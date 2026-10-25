/// I18n: gabungan kunci data (game-data/i18n/{en,ms,id}.json) dan teks app
/// khusus (assets/i18n_app/{en,ms,id}.json, awalan "ui.app."). Tiada teks
/// keras dalam widget — semua melalui t().
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/game_controller.dart';

class I18n {
  final String lang;
  final Map<String, String> _strings; // data + app digabung
  const I18n(this.lang, this._strings);

  /// Guna [dataStrings] (dari GameData) dan [appStrings] (assets i18n_app).
  /// Kunci app mengatasinya untuk awalan "ui.app." sahaja.
  factory I18n.merge({
    required String lang,
    required Map<String, String> dataStrings,
    required Map<String, String> appStrings,
  }) {
    final merged = <String, String>{...dataStrings};
    appStrings.forEach((k, v) {
      if (k.startsWith('ui.app.') || !merged.containsKey(k)) merged[k] = v;
    });
    return I18n(lang, merged);
  }

  static const I18n empty = I18n('en', {});

  String t(String key, [Map<String, Object?> args = const {}]) {
    var s = _strings[key] ?? key;
    for (final e in args.entries) {
      s = s.replaceAll('{${e.key}}', '${e.value}');
    }
    return s;
  }

  String? tryGet(String key) => _strings[key];

  bool has(String key) => _strings.containsKey(key);

  int get keyCount => _strings.length;
}

/// Teks app (assets/i18n_app/{en,ms,id}.json) — dimuat sekali pada main.
final Map<String, Map<String, String>> _appStringsCache = {};

Map<String, String> appStringsFor(String lang) =>
    _appStringsCache[lang] ?? const {};

Future<void> preloadAppStrings() async {
  for (final lang in const ['en', 'ms', 'id']) {
    final raw = await rootBundle.loadString('assets/i18n_app/$lang.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    _appStringsCache[lang] = decoded.map((k, v) => MapEntry(k, v as String));
  }
}

/// Provider I18n: gabung kunci data (GameData.i18n) + teks app.
final i18nProvider = Provider<I18n>((ref) {
  final st = ref.watch(gameControllerProvider).value;
  final data = ref.watch(gameDataProvider);
  final lang = st?.settings.lang ?? 'ms';
  if (data == null) return I18n.empty;
  return I18n.merge(
    lang: lang,
    dataStrings: data.i18n[lang] ?? const {},
    appStrings: appStringsFor(lang),
  );
});
