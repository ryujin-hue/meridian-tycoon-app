/// Skrin Syarikat: portfolio (+integration, prestasi minguan, cadangan),
/// Naik Tier (3 meter), milestone, kosmetik/KM Shop, leaderboard, Settings,
/// Bantuan "Cara Bermain".
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/i18n.dart';
import '../domain/economy.dart';
import '../domain/leaderboard.dart';
import '../game/scenes.dart';
import '../state/game_controller.dart';
import '../state/game_state.dart';
import 'common.dart';
import 'settings_screen.dart';
import 'widgets/pitch_sheet.dart';

class CompanyScreen extends ConsumerWidget {
  const CompanyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider).value;
    final data = ref.watch(gameDataProvider);
    final i18n = ref.watch(i18nProvider);
    if (state == null || data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final ctl = ref.read(gameControllerProvider.notifier);
    final check = ctl.tierCheck(state);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Naik Tier.
        SectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(i18n.t('ui.app.tier_up'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            for (final m in check.meters)
              MeterBar(
                label: i18n.t('ui.app.meter.${m.id}'),
                value: m.value,
                target: m.target,
                valueText: '${moneyCompact(m.value.round())} / ${moneyCompact(m.target.round())}',
                i18n: i18n,
              ),
            Text(i18n.t('ui.app.owns_target_tier',
                {'tier': state.tierIndex0 + 2}) +
                (check.ownsTargetTierCompany ? ' ✓' : '')),
            if (check.rewardDP > 0)
              Text('${i18n.t('ui.app.tier_reward')}: +${check.rewardDP} DP'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: check.canTierUp
                  ? () => _showTierCinematic(context, ref)
                  : null,
              child: Text(i18n.t('ui.app.confirm_tier_up')),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        // Portfolio.
        Text(i18n.t('ui.app.portfolio'),
            style: const TextStyle(fontWeight: FontWeight.w700)),
        for (final c in state.companies)
          _CompanyTile(owned: c, state: state, i18n: i18n),
        if (state.companies.isEmpty)
          Text(i18n.t('ui.app.market_refresh'), style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 10),
        // Pitch pelabur.
        _PitchCard(state: state, i18n: i18n),
        const SizedBox(height: 10),
        // Leaderboard.
        _LeaderboardCard(state: state, i18n: i18n),
        const SizedBox(height: 10),
        // Milestone.
        _MilestoneCard(state: state, i18n: i18n),
        const SizedBox(height: 10),
        // Kosmetik / KM Shop.
        _CosmeticsCard(state: state, i18n: i18n),
        const SizedBox(height: 10),
        // Settings & Bantuan.
        ListTile(
          leading: const Icon(Icons.settings),
          title: Text(i18n.t('ui.app.settings')),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: Text(i18n.t('ui.app.help')),
          onTap: () => _showHelp(context, i18n),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  void _showTierCinematic(BuildContext context, WidgetRef ref) {
    final data = ref.read(gameDataProvider)!;
    final state = ref.read(gameControllerProvider).value!;
    Navigator.push(context, MaterialPageRoute(builder: (_) => TierUpCinematicPage(
      game: TierCinematicGame(
        data,
        state.tierIndex0 + 1,
        reduceMotion: state.settings.reduceMotion,
        onComplete: () async {
          await ref.read(gameControllerProvider.notifier).confirmTierUp();
          if (context.mounted) Navigator.pop(context);
        },
      ),
    )));
  }

  void _showHelp(BuildContext context, I18n i18n) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final step in [
                  'overnight_title', 'collect_all', 'category.midmarket', 'bid_plus5',
                  'net_contribution', 'tab.staff', 'tab.research', 'pitch.title',
                  'tier_up', 'debt',
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      const Icon(Icons.arrow_right, size: 18),
                      Expanded(child: Text(i18n.t('ui.app.$step'))),
                    ]),
                  ),
                Text(i18n.t('ui.msg.premium_note'),
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompanyTile extends ConsumerWidget {
  final OwnedCompany owned;
  final GameState state;
  final I18n i18n;
  const _CompanyTile({required this.owned, required this.state, required this.i18n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(gameDataProvider)!;
    final ctl = ref.read(gameControllerProvider.notifier);
    final contribution = companyNetPerHour(
        data.balance, owned.snap.grossPerHourK, owned.integrationLevel);
    final cost = (owned.snap.ntValue * 0.25 * (owned.integrationLevel + 1)).round();
    final suggestionKey = owned.weekScore >= 0 ? 'ui.app.action_invest' : 'ui.app.action_hold';
    // Cadangan tindakan dipaparkan sebagai label (D6).
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(i18n.t(owned.snap.nameKey)),
      subtitle: Text(
          '${i18n.t('ui.app.integration')}: L${owned.integrationLevel} · ${i18n.t('ui.app.net_contribution')}: ${money(contribution.round())}/j · ${i18n.t(suggestionKey)}'),
      trailing: owned.integrationLevel >= 5
          ? Text(i18n.t('ui.app.max_level'))
          : FilledButton.tonal(
              onPressed: () => ctl.upgradeIntegration(owned.snap.id),
              child: Text('${i18n.t('ui.app.integration_cost')}: ${money(cost)}')),
      isThreeLine: true,
    );
  }
}

class _PitchCard extends ConsumerWidget {
  final GameState state;
  final I18n i18n;
  const _PitchCard({required this.state, required this.i18n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctl = ref.read(gameControllerProvider.notifier);
    final ready = ctl.pitchReady(state);
    return SectionCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.record_voice_over),
        title: Text(i18n.t('ui.app.pitch.title')),
        subtitle: Text(ready
            ? '${i18n.t('ui.app.pitch.ready')} · slot: ${ctl.pitchSlots(state)}'
            : '${i18n.t('ui.app.pitch.cooldown')}: 24j'),
        trailing: FilledButton.tonal(
          onPressed: ready
              ? () => showModalBottomSheet(
                  context: context, builder: (_) => const PitchSheet())
              : null,
          child: Text(i18n.t('ui.btn.pitch')),
        ),
      ),
    );
  }
}

class _LeaderboardCard extends ConsumerWidget {
  final GameState state;
  final I18n i18n;
  const _LeaderboardCard({required this.state, required this.i18n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(gameDataProvider)!;
    final utc = DateTime.now().toUtc();
    final league = buildLeague(
      data: data.leaderboard,
      utc: utc,
      playerScore: state.weekScore,
      playerTier: state.tierIndex0 + 1,
      playerWeekGain: state.weekScore,
    );
    return SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(i18n.t('ui.app.leaderboard'),
            style: const TextStyle(fontWeight: FontWeight.w700)),
        for (final e in league.take(5))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Text('${league.indexOf(e) + 1}'),
            title: Text(e.isPlayer ? i18n.t('ui.app.league.you') : i18n.t(e.nameKey)),
            trailing: Text(money(e.score)),
          ),
      ]),
    );
  }
}

class _MilestoneCard extends ConsumerWidget {
  final GameState state;
  final I18n i18n;
  const _MilestoneCard({required this.state, required this.i18n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(gameDataProvider)!;
    return SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(i18n.t('ui.app.milestones'),
            style: const TextStyle(fontWeight: FontWeight.w700)),
        for (final m in data.milestones.take(6))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(state.claimedMilestones.contains(m.id)
                ? Icons.emoji_events
                : Icons.radio_button_unchecked),
            title: Text(i18n.t(m.nameKey)),
            subtitle: Text(i18n.t(m.descKey)),
            trailing: Text('+${m.reward.dp ?? 0}DP'),
          ),
      ]),
    );
  }
}

class _CosmeticsCard extends ConsumerWidget {
  final GameState state;
  final I18n i18n;
  const _CosmeticsCard({required this.state, required this.i18n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(gameDataProvider)!;
    final ctl = ref.read(gameControllerProvider.notifier);
    final owned = state.claimedLiveOps.where((k) => k.startsWith('cos:')).toSet();
    return SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(i18n.t('ui.app.km_shop'),
            style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(i18n.t('ui.app.coming_soon_note'),
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        for (final c in data.cosmetics.take(4))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.palette),
            title: Text(i18n.t(c.nameKey)),
            trailing: owned.contains('cos:${c.id}')
                ? Text(i18n.t('ui.app.owned'))
                : TextButton(
                    onPressed: () => ctl.buyCosmetic(c.id),
                    child: Text('${c.priceKM} KM')),
          ),
      ]),
    );
  }
}

String money(int v) => v.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
