/// Save repository: JSON berversi, penulisan ATOMIK + sandaran.
/// Abstrak: fail sebenar (produksi) / memori (test — elak IO dalam fake-async).
library;

import 'dart:convert';
import 'dart:io';

import '../state/game_state.dart';

abstract class SaveRepository {
  const SaveRepository();

  Future<GameState?> load();
  Future<void> save(GameState state);

  static String export(GameState state) => jsonEncode(state.toJson());
  static GameState import(String json) =>
      GameState.fromJson(jsonDecode(json) as Map<String, dynamic>);
}

/// Simpanan berasaskan fail (produksi): atomic write + backup.
class FileSaveRepository extends SaveRepository {
  final Future<Directory> Function() docsDir;
  const FileSaveRepository(this.docsDir);

  Future<File> _saveFile() async => File('${(await docsDir()).path}/save.json');
  Future<File> _backupFile() async =>
      File('${(await docsDir()).path}/save.backup.json');

  @override
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

  @override
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
}

/// Simpanan dalam memori (test/widget).
class MemorySaveRepository extends SaveRepository {
  GameState? state;
  int saves = 0;
  @override
  Future<GameState?> load() async => state;
  @override
  Future<void> save(GameState state) async {
    this.state = state;
    saves++;
  }
}
