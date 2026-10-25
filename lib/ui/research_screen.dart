/// Skrin Research: 3 pohon (operasi/pasaran/merger) x 4 peringkat, dibeli DP,
/// dibuka ikut tier, kesan tetap dengan had keras daripada data.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/i18n.dart';
import '../state/game_state.dart';
import '../state/game_controller.dart';
import 'common.dart';

class ResearchScreen extends ConsumerWidget {
  const ResearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider).value;
    final data = ref.watch(gameDataProvider);
    final i18n = ref.watch(i18nProvider);
    if (state == null || data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final trees = data.research.map((n) => n.tree).toSet().toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SectionCard(
          child: Text('DP: ${state.dp}', style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        for (final tree in trees)
          SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(i18n.t('ui.app.tree.$tree'),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              for (final node in data.research.where((n) => n.tree == tree))
                _NodeTile(node: node, state: state, i18n: i18n),
            ]),
          ),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _NodeTile extends ConsumerWidget {
  final dynamic node;
  final GameState state;
  final I18n i18n;
  const _NodeTile({required this.node, required this.state, required this.i18n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctl = ref.read(gameControllerProvider.notifier);
    final stage = state.research[node.id] ?? 0;
    final locked = node.unlockTier > state.tierIndex0 + 1;
    final maxed = stage >= 4;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        maxed ? Icons.check_circle : stage > 0 ? Icons.trending_up : Icons.lock,
        color: locked ? Colors.grey : null,
      ),
      title: Text(i18n.t(node.nameKey)),
      subtitle: Text(
          '${i18n.t(node.descKey)}\n${i18n.t('ui.app.stage', {'a': stage})} · ${node.effect.type} +${node.effect.perStageValue} (maks ${node.effect.hardCapValue})'),
      isThreeLine: true,
      trailing: maxed
          ? Text(i18n.t('ui.app.max_level'))
          : locked
              ? Text(i18n.t('ui.msg.tier_locked'))
              : FilledButton.tonal(
                  onPressed: () => ctl.buyResearch(node.id),
                  child: Text('${i18n.t('ui.app.dp_cost')}: ${node.costDP}DP')),
    );
  }
}
