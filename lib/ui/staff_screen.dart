/// Skrin Staf: 5 peranan, upah dari pool ikut slot, gaji harian terikat tier,
/// kemahiran aktif dengan cooldown, sinergi kecil.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/i18n.dart';
import '../data/models.dart';
import '../domain/staff.dart';
import '../state/game_controller.dart';
import '../state/game_state.dart';
import 'common.dart';

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider).value;
    final data = ref.watch(gameDataProvider);
    final i18n = ref.watch(i18nProvider);
    if (state == null || data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 60000;
    final tier = data.tiers[state.tierIndex0];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SectionCard(
          child: Text(
              '${i18n.t('ui.app.tab.staff')} (${state.staff.length}/${tier.maxStaff})',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        // Staf diupah.
        for (final h in state.staff)
          _HiredTile(hired: h, state: state, i18n: i18n, now: now),
        const SizedBox(height: 8),
        // Pool upah: 5 peranan x pilihan bintang (daripada staff_pool data).
        SectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(i18n.t('ui.btn.hire'), style: const TextStyle(fontWeight: FontWeight.w700)),
            for (final role in data.staffRoles)
              _RolePool(role: role, state: state, i18n: i18n, data: data),
          ]),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _HiredTile extends ConsumerWidget {
  final HiredStaff hired;
  final GameState state;
  final I18n i18n;
  final int now;
  const _HiredTile({required this.hired, required this.state, required this.i18n, required this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.read(gameDataProvider)!;
    final ctl = ref.read(gameControllerProvider.notifier);
    final role = data.staffRoles.firstWhere((r) => r.id == hired.roleId);
    final member = data.staffPool.firstWhere((m) => m.id == hired.staffId);
    final cd = state.skillCooldown[hired.staffId] ?? 0;
    final ready = cd <= now && hired.star >= role.activeSkill.unlockStar;
    return ListTile(
      dense: true,
      leading: Text('★${hired.star}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      title: Text(i18n.t(member.nameKey)),
      subtitle: Text(
          '${i18n.t(role.nameKey)} · ${i18n.t('ui.app.salary')}: ${money(dailySalary(role, state.tierIndex0))}'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          tooltip: i18n.t('ui.app.use_skill'),
          onPressed: ready
              ? () => ctl.useSkill(hired.staffId)
              : null,
          icon: const Icon(Icons.bolt),
        ),
        IconButton(
          tooltip: i18n.t('ui.app.fire'),
          onPressed: () => ctl.fireStaff(hired.staffId),
          icon: const Icon(Icons.person_remove),
        ),
      ]),
    );
  }
}

class _RolePool extends ConsumerWidget {
  final StaffRole role;
  final GameState state;
  final I18n i18n;
  final GameData data;
  const _RolePool({required this.role, required this.state, required this.i18n, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctl = ref.read(gameControllerProvider.notifier);
    final candidates = data.staffPool
        .where((m) => m.role == role.id)
        .where((m) => !state.staff.any((h) => h.staffId == m.id))
        .toList()
      ..sort((a, b) => a.star.compareTo(b.star));
    if (candidates.isEmpty) return const SizedBox.shrink();
    final member = candidates.first; // termurah dahulu
    final cost = hireCost(role, member, state.tierIndex0,
        reductionPct: ctl.passiveForUi(state, 'hire_cost_reduction'));
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Text('★${member.star}'),
      title: Text(i18n.t(role.nameKey)),
      subtitle: Text(
          '${i18n.t('ui.app.passive')}: ${role.passive.perStarPct}%/★ · ${i18n.t('ui.app.salary')}: ${money(dailySalary(role, state.tierIndex0))}'),
      trailing: FilledButton.tonal(
        onPressed: () => ctl.hireStaff(member.id),
        child: Text(money(cost)),
      ),
    );
  }
}
