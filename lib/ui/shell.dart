/// Shell 5 tab tetap (Peraturan 2-tap): Markas, Pasar, Staf, Research, Syarikat.
/// Bar tindakan pantas: Kutip Semua sentiasa tersedia (1 ketukan dari mana-mana).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/i18n.dart';
import '../state/game_controller.dart';
import '../state/game_state.dart';
import 'company_screen.dart';
import 'hq_screen.dart';
import 'market_screen.dart';
import 'research_screen.dart';
import 'staff_screen.dart';

class GameShell extends ConsumerStatefulWidget {
  const GameShell({super.key});

  @override
  ConsumerState<GameShell> createState() => _GameShellState();
}

class _GameShellState extends ConsumerState<GameShell> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Jeda enjin Flame apabila di latar belakang (Prestasi) — dikendalikan
    // oleh adegan melalui TickerMode; proses dunia semasa kembali.
    if (state == AppLifecycleState.resumed) {
      ref.read(gameControllerProvider.notifier).backgroundDataUpdateCheck();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(gameControllerProvider);
    final i18n = ref.watch(i18nProvider);
    final state = async.value;

    if (async.isLoading || state == null) {
      return Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(i18n.t(state == null ? 'ui.msg.loading' : 'ui.app.error')),
          ]),
        ),
      );
    }

    return Scaffold(
      appBar: _appBar(context, i18n, state),
      body: IndexedStack(
        index: _tab,
        children: const [
          HqScreen(),
          MarketScreen(),
          StaffScreen(),
          ResearchScreen(),
          CompanyScreen(),
        ],
      ),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        _quickBar(context, i18n, state),
        NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: [
            NavigationDestination(icon: const Icon(Icons.business), label: i18n.t('ui.app.tab.hq')),
            NavigationDestination(icon: const Icon(Icons.gavel), label: i18n.t('ui.app.tab.market')),
            NavigationDestination(icon: const Icon(Icons.badge), label: i18n.t('ui.app.tab.staff')),
            NavigationDestination(icon: const Icon(Icons.science), label: i18n.t('ui.app.tab.research')),
            NavigationDestination(icon: const Icon(Icons.domain), label: i18n.t('ui.app.tab.company')),
          ],
        ),
      ]),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context, I18n i18n, GameState s) {
    final fmt = i18n.t;
    return AppBar(
      title: Text('Meridian Tycoon — ${fmt('tier.t${s.tierIndex0 + 1}.title')}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            StatChipLite('TM', money(s.tm)),
            const SizedBox(width: 6),
            StatChipLite('DP', '${s.dp}'),
            const SizedBox(width: 6),
            StatChipLite('KM', '${s.km}'),
            const SizedBox(width: 6),
            StatChipLite('★', '${s.reputation.round()}'),
          ]),
        ),
      ],
    );
  }

  Widget _quickBar(BuildContext context, I18n i18n, GameState s) {
    final ctl = ref.read(gameControllerProvider.notifier);
    final pend = ctl.pendingIncome(s);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => ctl.collect(),
              icon: const Icon(Icons.monetization_on),
              label: Text(
                  '${i18n.t('ui.app.collect_all')} · +${moneyCompact(pend.amount)}'),
            ),
          ),
        ]),
      ),
    );
  }
}

class StatChipLite extends StatelessWidget {
  final String label;
  final String value;
  const StatChipLite(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end,
        children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    ]);
  }
}

String money(int v) => v.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
String moneyCompact(int v) =>
    v >= 1000000 ? '${(v / 1000000).toStringAsFixed(1)}M' : money(v);
