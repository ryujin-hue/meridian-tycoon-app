/// Pitch pelabur: sudut Growth/Safety/Story, kebarangkalian dipaparkan
/// sebelum sahkan; cooldown 24 jam; kegagalan memberi petunjuk berguna.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/i18n.dart';
import '../../domain/pitch.dart';
import '../../state/game_controller.dart';

class PitchSheet extends ConsumerWidget {
  const PitchSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider);
    final state = ref.watch(gameControllerProvider).value!;
    final data = ref.watch(gameDataProvider)!;
    final ctl = ref.read(gameControllerProvider.notifier);

    final growthOk = ctl.netDailyIncomeForUi(state) >=
        data.tiers[state.tierIndex0].targetDailyNetIncome;
    final safetyOk = state.debt.principal == 0;
    final storyOk = state.companies.any((c) => c.snap.category == 'legacy');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(i18n.t('ui.app.pitch.title'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          for (final angle in kPitchAngles)
            Card(
              child: ListTile(
                title: Text(angle.id.toUpperCase()),
                subtitle: Text(
                    '${i18n.t(angle.conditionDesc)} · ${i18n.t('ui.app.pitch.chance')}: ${(pitchProbability(
                      reputation: state.reputation,
                      angle: angle,
                      growthConditionMet: growthOk,
                      safetyConditionMet: safetyOk,
                      storyConditionMet: storyOk,
                    ) * 100).toStringAsFixed(0)}%'),
                onTap: () async {
                  await ctl.pitch(angle.id);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ),
        ]),
      ),
    );
  }
}
