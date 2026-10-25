/// Tutorial 10 langkah daripada data dengan spotlight ringkas.
/// Langkah dipacu `requiredAction` melalui tindakan controller.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/i18n.dart';
import '../../state/game_controller.dart';
import '../../state/game_state.dart';

class TutorialSpotlight extends ConsumerWidget {
  final GameState state;
  final I18n i18n;
  const TutorialSpotlight({super.key, required this.state, required this.i18n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.tutorialStep > 10) return const SizedBox.shrink();
    final data = ref.read(gameDataProvider)!;
    final step = data.tutorial.steps
        .firstWhere((s) => s.step == state.tutorialStep, orElse: () => data.tutorial.steps.first);
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('${i18n.t(step.titleKey)} (${step.step}/10)',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 4),
          Text(i18n.t(step.descKey)),
        ]),
      ),
    );
  }
}

/// Dialog penamaan CEO (langkah 1: enter_name_and_sector).
class NamingDialog extends ConsumerStatefulWidget {
  const NamingDialog({super.key});

  @override
  ConsumerState<NamingDialog> createState() => _NamingDialogState();
}

class _NamingDialogState extends ConsumerState<NamingDialog> {
  final _name = TextEditingController();
  String _sector = 'app';

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    final data = ref.watch(gameDataProvider)!;
    return AlertDialog(
      title: Text(i18n.t('ui.app.naming_title')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _name, maxLength: 20,
            decoration: InputDecoration(labelText: i18n.t('ui.app.naming_title'))),
        const SizedBox(height: 8),
        ...data.sectors.map((s) => ListTile(
              leading: Icon(_sector == s.id
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
                  semanticLabel: s.id),
              title: Text(i18n.t(s.nameKey)),
              subtitle: Text(i18n.t(s.descKey)),
              onTap: () => setState(() => _sector = s.id),
            )),
      ]),
      actions: [
        FilledButton(
          onPressed: () {
            ref
                .read(gameControllerProvider.notifier)
                .namingComplete(_name.text.trim().isEmpty ? 'CEO' : _name.text.trim(), _sector);
            Navigator.pop(context);
          },
          child: Text(i18n.t('ui.app.tutorial.next')),
        ),
      ],
    );
  }
}
