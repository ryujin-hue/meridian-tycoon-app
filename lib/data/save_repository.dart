/// Save repository: JSON berversi, penulisan ATOMIK + sandaran.
/// Fail: save.json (semasa), save.backup.json (salinan sebelumnya).
library;

import 'dart:convert';
import 'dart:io';

import '../state/game_state.dart';

class SaveRepository {
  final Future<Directory> Function() docsDir;
  SaveRepository(this.docsDir);

  Future<File> _saveFile() async =>
      File('${(await docsDir()).path}/save.json');
  Future<File> _backupFile() async =>
      File('${(await docsDir()).path}/save.backup.json');

  /// Baca save; null jika tiada/rosak (rosak → cuba sandaran).
  Future<GameState?> load() async {
    final f = await _saveFile();
    if (await f.exists()) {
      try {
        final s = await f.readAsString();
        return GameState.fromJson(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {
        // jatuh ke sandaran
      }
    }
    final b = await _backupFile();
    if (await b.exists()) {
      try {
        final s = await b.readAsString();
        return GameState.fromJson(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {}
    }
    return null;
  }

  /// Penulisan atomik: tulis fail sementara, renama; salinan lama jadi sandaran.
  Future<void> save(GameState state) async {
    final f = await _saveFile();
    final tmp = File('${f.path}.tmp');
    if (await f.exists()) {
      final b = await _backupFile();
      await f.copy(b.path);
    }
    await tmp.writeAsString(jsonEncode(state.toJson()), flush: true);
    if (await f.exists()) {
      await f.delete();
    }
    await tmp.rename(f.path);
  }

  /// Eksport save sebagai string JSON (untuk import/eksport manual).
  static String export(GameState state) => jsonEncode(state.toJson());

  /// Import; baling FormatException jika rosak.
  static GameState import(String json) =>
      GameState.fromJson(jsonDecode(json) as Map<String, dynamic>);
}
