/// Skrin Markas: header status, HQ Diorama (Flame), kad operasi, Kutip Semua,
/// sasaran minguan, Ringkasan Semalaman (sheet) pada buka pertama sesi.
library;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/i18n.dart';
import '../data/models.dart';
import '../domain/economy.dart';
import '../domain/liveops.dart';
import '../game/hq_diorama_scene.dart';
import '../state/game_controller.dart';
import '../state/game_state.dart';
import 'common.dart';
import 'widgets/overnight_sheet.dart';
import 'widgets/tutorial_spotlight.dart';

class HqScreen extends ConsumerStatefulWidget {
  const HqScreen({super.key});

  @override
  ConsumerState<HqScreen> createState() => _HqScreenState();
}

class _HqScreenState extends ConsumerState<HqScreen> {
  bool _summaryShown = false;
  HqDioramaGame? _game;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameControllerProvider).value;
    final data = ref.watch(gameDataProvider);
    final i18n = ref.watch(i18nProvider);
    if (state == null || data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final ctl = ref.read(gameControllerProvider.notifier);
    final reduceMotion = state.settings.reduceMotion;

    // Ringkasan Semalaman sekali per buka app (aliran sesi GDD).
    if (!_summaryShown) {
      _summaryShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showModalBottomSheet(
          context: context,
          isDismissible: true,
          builder: (_) => OvernightSheet(summary: ctl.buildSummary(state)),
        );
      });
    }

    final contract = pickDailyContract(data.events, DateTime.now().toUtc(), state.tierIndex0);
    final weekly = pickWeeklyTarget(data.events, DateTime.now().toUtc(), state.tierIndex0);

    _game ??= HqDioramaGame(data, () =>
        ref.read(gameControllerProvider).value ?? state,
        reduceMotion: reduceMotion);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // HQ Diorama.
        SectionCard(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 200,
              child: reduceMotion
                  ? _staticDiorama(state)
                  : GameWidget(game: _game!),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Kad operasi.
        SectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${i18n.t('ui.app.ops_slots')} (${state.ops.length}/${data.tiers[state.tierIndex0].maxOperations})',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...state.ops.map((slot) => _opRow(context, ref, i18n, state, slot)),
            if (state.ops.length < data.tiers[state.tierIndex0].maxOperations)
              _newOpRow(context, ref, i18n, state, data),
          ]),
        ),
        const SizedBox(height: 10),
        // Sasaran minguan + kontrak harian.
        if (weekly != null)
          SectionCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag),
              title: Text(i18n.t(weekly.titleKey)),
              subtitle: Text(i18n.t(weekly.descKey)),
              trailing: Text('${state.weeklyTargetProgress}/${weekly.goal.amount}'),
            ),
          ),
        if (contract != null && state.dailyContractId == contract.id)
          SectionCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.today),
              title: Text(i18n.t(contract.titleKey)),
              subtitle: Text(i18n.t(contract.descKey)),
              trailing: Text('${state.dailyContractProgress}/${contract.goal.amount}'),
            ),
          ),
        TutorialSpotlight(state: state, i18n: i18n),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _staticDiorama(GameState state) => Container(
        color: const Color(0xFF0E1420),
        alignment: Alignment.center,
        child: const Icon(Icons.business, size: 64, color: Color(0xFF3A4B66)),
      );

  Widget _opRow(BuildContext context, WidgetRef ref, I18n i18n, GameState state, OpSlot slot) {
    final data = ref.read(gameDataProvider)!;
    final op = data.operations.firstWhere((o) => o.id == slot.opId);
    final ctl = ref.read(gameControllerProvider.notifier);
    final cost = opUpgradeCost(op, slot.level,
        reductionPct: 0);
    final maxed = slot.level >= op.maxLevel;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(i18n.t(op.nameKey)),
      subtitle: Text(
          'L${slot.level} · ${money(opIncomePerHour(op, slot.level).round())}/j'),
      trailing: maxed
          ? Text(i18n.t('ui.app.max_level'))
          : FilledButton.tonal(
              onPressed: () => ctl.upgradeOp(op.id),
              child: Text('${i18n.t('ui.app.upgrade_cost')}: ${money(cost)}')),
    );
  }

  Widget _newOpRow(BuildContext context, WidgetRef ref, I18n i18n, GameState state, GameData data) {
    final ctl = ref.read(gameControllerProvider.notifier);
    final available = data.operations
        .where((o) => o.unlockTier <= state.tierIndex0 + 1)
        .where((o) => !state.ops.any((s) => s.opId == o.id))
        .toList();
    if (available.isEmpty) return const SizedBox.shrink();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.add_circle_outline),
      title: Text(i18n.t(available.first.nameKey)),
      subtitle: Text(i18n.t(available.first.descKey)),
      trailing: FilledButton.tonal(
        onPressed: () => ctl.upgradeOp(available.first.id),
        child: Text(money(opUpgradeCost(available.first, 0))),
      ),
    );
  }
}
