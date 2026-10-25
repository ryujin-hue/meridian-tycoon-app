/// Settings: bahasa, tema, bunyi, getaran, notifikasi, reduce motion,
/// versi data + sumber, "Check for data update", "Reset to bundled data",
/// eksport/import save.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config.dart';
import '../../app/i18n.dart';
import '../../data/save_repository.dart';
import '../../state/game_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider).value;
    final data = ref.watch(gameDataProvider);
    final i18n = ref.watch(i18nProvider);
    if (state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final ctl = ref.read(gameControllerProvider.notifier);
    final s = state.settings;

    return Scaffold(
      appBar: AppBar(title: Text(i18n.t('ui.app.settings'))),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          // Bahasa.
          ListTile(
            title: Text(i18n.t('ui.app.settings.language')),
            subtitle: Text(s.lang.toUpperCase()),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'en', label: Text('EN')),
                ButtonSegment(value: 'ms', label: Text('MS')),
                ButtonSegment(value: 'id', label: Text('ID')),
              ],
              selected: {s.lang},
              onSelectionChanged: (v) => ctl.setLanguage(v.first),
            ),
          ),
          SwitchListTile(
            title: Text(i18n.t('ui.app.settings.theme')),
            value: s.darkMode,
            onChanged: (v) => ctl.updateSettings(s.copyWith(darkMode: v)),
          ),
          SwitchListTile(
            title: Text(i18n.t('ui.app.settings.sound')),
            value: s.sound,
            onChanged: (v) => ctl.updateSettings(s.copyWith(sound: v)),
          ),
          SwitchListTile(
            title: Text(i18n.t('ui.app.settings.vibrate')),
            value: s.vibrate,
            onChanged: (v) => ctl.updateSettings(s.copyWith(vibrate: v)),
          ),
          SwitchListTile(
            title: Text(i18n.t('ui.app.settings.notifications')),
            subtitle: Text(i18n.t('ui.app.notif_note')),
            value: s.notifications,
            onChanged: (v) => ctl.updateSettings(s.copyWith(notifications: v)),
          ),
          SwitchListTile(
            title: Text(i18n.t('ui.app.settings.reduce_motion')),
            subtitle: const Text('Lottie · Rive · Flame particles OFF'),
            value: s.reduceMotion,
            onChanged: (v) => ctl.updateSettings(s.copyWith(reduceMotion: v)),
          ),
          const Divider(),
          // Data.
          ListTile(
            title: Text(i18n.t('ui.app.settings.data_version')),
            subtitle: Text(
                '${data?.dataVersion ?? '-'} · ${i18n.t('ui.app.settings.data_source')}: ${state.dataVersionAtSave == AppConfig.appVersion ? 'bundled' : 'cache/remote'}'),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_download),
            title: Text(i18n.t('ui.app.settings.check_update')),
            onTap: () async {
              await ctl.backgroundDataUpdateCheck();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(i18n.t('ui.app.settings.check_update'))));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: Text(i18n.t('ui.app.settings.reset_bundled')),
            onTap: () async {
              await ctl.resetToBundled();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(i18n.t('ui.app.settings.reset_done'))));
              }
            },
          ),
          const Divider(),
          // Save.
          ListTile(
            leading: const Icon(Icons.upload),
            title: Text(i18n.t('ui.app.settings.export')),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: SaveRepository.export(state)));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(i18n.t('ui.app.settings.export_done'))));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: Text(i18n.t('ui.app.settings.import')),
            onTap: () async {
              final text = await Clipboard.getData('text/plain');
              final raw = text?.text;
              if (raw == null) return;
              try {
                final imported = SaveRepository.import(raw);
                // Ganti save semasa (atomik melalui repository).
                final repo = SaveRepository(ref.read(gameDepsProvider).docsDir);
                await repo.save(imported);
                if (context.mounted) Navigator.pop(context);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid save')));
                }
              }
            },
          ),
          ListTile(
            title: const Text('App'),
            subtitle: const Text('v${AppConfig.appVersion} · DATA_REF=${AppConfig.dataRef}'),
          ),
        ],
      ),
    );
  }
}
