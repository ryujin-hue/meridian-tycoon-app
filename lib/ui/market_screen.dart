/// Skrin Pasar: tab kategori, kad sasaran (julat ±8%), lelongan aktif,
/// bottom sheet bidaan (preset +5/+10%, tersuai, leverage, yuran),
/// rundingan Mega/Legacy. Adegan City Skyline sebagai header.
library;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/i18n.dart';
import '../data/models.dart';
import '../domain/auction.dart';
import '../domain/economy.dart';
import '../game/scenes.dart';
import '../state/game_controller.dart';
import '../state/game_state.dart';
import 'common.dart';

const List<String> kCategories = [
  'starter', 'midmarket', 'rare', 'mega', 'legacy',
];

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: kCategories.length, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameControllerProvider).value;
    final data = ref.watch(gameDataProvider);
    final i18n = ref.watch(i18nProvider);
    if (state == null || data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(children: [
      // Header: City Skyline (sasaran sebagai bangunan).
      SizedBox(
        height: 110,
        child: state.settings.reduceMotion
            ? const SizedBox.shrink()
            : ClipRect(
                child: GameWidget(
                  game: CitySkylineGame(data, () =>
                      ref.read(gameControllerProvider).value ?? state),
                ),
              ),
      ),
      TabBar(
        controller: _tabs,
        isScrollable: true,
        tabs: [
          for (final c in kCategories) Tab(text: i18n.t('ui.app.category.$c')),
        ],
      ),
      Expanded(
        child: TabBarView(
          controller: _tabs,
          children: [
            for (final c in kCategories)
              _CategoryList(category: c, state: state, i18n: i18n, data: data),
          ],
        ),
      ),
      // Lelongan aktif.
      if (state.auctions.isNotEmpty)
        SafeArea(
          child: SizedBox(
            height: 132,
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
                  child: Text(i18n.t('ui.app.auction_active'),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                for (final a in state.auctions)
                  _AuctionRow(auction: a, i18n: i18n, state: state),
              ],
            ),
          ),
        ),
      const SizedBox.shrink(),
      // ruang untuk tutorialAction open_market
      ...[],
    ]);
  }
}

class _CategoryList extends ConsumerWidget {
  final String category;
  final GameState state;
  final I18n i18n;
  final GameData data;
  const _CategoryList({required this.category, required this.state, required this.i18n, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 60000;
    final targets = state.market
        .where((t) => t.snap.category == category)
        .where((t) => t.visibleUntilMinute > now)
        .toList();
    if (targets.isEmpty) {
      return Center(child: Text(i18n.t('ui.app.market_refresh')));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final t in targets) _TargetCard(target: t, i18n: i18n, state: state, data: data),
      ],
    );
  }
}

class _TargetCard extends ConsumerWidget {
  final MarketTarget target;
  final I18n i18n;
  final GameState state;
  final GameData data;
  const _TargetCard({required this.target, required this.i18n, required this.state, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctl = ref.read(gameControllerProvider.notifier);
    final sectorColor = MeridianSectorColor.of(ref, target.snap.sector);
    final est = estimateRange(target.snap.id, target.snap.ntValue);
    final revealed = (state.scanReveal[target.snap.id] ?? 0) >
        DateTime.now().toUtc().millisecondsSinceEpoch ~/ 60000;
    final alreadyOwned = state.companies.any((c) => c.snap.id == target.snap.id);
    final active = state.auctions.any((a) => a.target.id == target.snap.id);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 10, height: 10,
                decoration: BoxDecoration(color: sectorColor, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(i18n.t(target.snap.nameKey),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Text('${i18n.t('ui.app.tier')} ${target.snap.tier}'),
          ]),
          const SizedBox(height: 4),
          Text(
            revealed
                ? '${i18n.t('ui.app.exact_value')}: ${money(target.snap.ntValue)}'
                : '${i18n.t('ui.app.estimate_range')}: ${money(est.low)} – ${money(est.high)}',
            style: TextStyle(color: revealed ? Colors.green : Colors.grey),
          ),
          Text('${i18n.t('ui.app.payback')}: ${target.snap.category == 'legacy' ? '★' : ''}${target.snap.ntValue ~/ 1000}k'),
          const SizedBox(height: 8),
          if (alreadyOwned)
            Text(i18n.t('ui.app.owned'), style: const TextStyle(color: Colors.grey))
          else if (active)
            Text(i18n.t('ui.app.auction_active'), style: const TextStyle(color: Colors.grey))
          else
            FilledButton(
              onPressed: () => ctl.startAuction(target.snap.id),
              child: Text(i18n.t('ui.app.start_auction')),
            ),
        ]),
      ),
    );
  }
}

class _AuctionRow extends ConsumerWidget {
  final AuctionState auction;
  final I18n i18n;
  final GameState state;
  const _AuctionRow({required this.auction, required this.i18n, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 60000;
    final ctl = ref.read(gameControllerProvider.notifier);
    // Rundingan tertunggak (Mega/Legacy round 2 dimenangi).
    if (auction.clauses != null) {
      return ListTile(
        dense: true,
        leading: const Icon(Icons.handshake, color: Colors.amber),
        title: Text(i18n.t(auction.target.nameKey)),
        subtitle: Text(i18n.t('ui.app.negotiation_title')),
        trailing: FilledButton.tonal(
          onPressed: () => _openNegotiation(context, ref, ctl),
          child: Text(i18n.t('ui.app.season_claim')),
        ),
      );
    }
    final left = auction.endMinute - now;
    final r2 = auction.target.isMegaOrLegacy && auction.round == 2;
    return ListTile(
      dense: true,
      leading: const Icon(Icons.gavel),
      title: Text(i18n.t(auction.target.nameKey)),
      subtitle: Text(
          '${i18n.t('ui.app.current_price')}: ${money(auction.currentPrice)} · ${i18n.t('ui.app.time_left')}: ${left.clamp(0, 9999)}m'
          '${r2 ? ' · ${i18n.t('ui.app.round', {'n': 2})}' : ''}'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          tooltip: 'Auction Room',
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => AuctionRoomPage(auctionId: auction.id))),
          icon: const Icon(Icons.theater_comedy),
        ),
        Text(
          auction.leader == null
              ? i18n.t('ui.app.no_bidder')
              : auction.leader == 'player'
                  ? i18n.t('ui.app.you')
                  : i18n.t(auction.leader!),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ]),
      onTap: () => _openBidSheet(context, ref),
    );
  }

  void _openBidSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => BidSheet(auction: auction),
    );
  }

  Future<void> _openNegotiation(
      BuildContext context, WidgetRef ref, GameController ctl) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (_) => NegotiationSheet(auction: auction),
    );
    if (picked != null) {
      await ctl.applyNegotiationClause(auction.id, picked);
    }
  }
}

/// Halaman Auction Room penuh (adegan Flame).
class AuctionRoomPage extends StatelessWidget {
  final String auctionId;
  const AuctionRoomPage({super.key, required this.auctionId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auction Room')),
      body: Consumer(builder: (context, ref, _) {
        final data = ref.watch(gameDataProvider)!;
        final state = ref.watch(gameControllerProvider).value!;
        final reduceMotion = state.settings.reduceMotion;
        if (reduceMotion) {
          return const Center(child: Icon(Icons.gavel, size: 64));
        }
        return GameWidget(
          game: AuctionRoomGame(
            data,
            () => ref.read(gameControllerProvider).value,
            auctionId,
          ),
        );
      }),
    );
  }
}

/// Bottom sheet bidaan: preset +5%/+10% atau tersuai; yuran, leverage,
/// tunai diperlukan — semuanya dipaparkan SEBELUM sahkan (Peraturan F).
class BidSheet extends ConsumerStatefulWidget {
  final AuctionState auction;
  const BidSheet({super.key, required this.auction});

  @override
  ConsumerState<BidSheet> createState() => _BidSheetState();
}

class _BidSheetState extends ConsumerState<BidSheet> {
  final _custom = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    final state = ref.watch(gameControllerProvider).value!;
    final data = ref.watch(gameDataProvider)!;
    final ctl = ref.read(gameControllerProvider.notifier);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 60000;
    final a = simulateAuction(widget.auction, now);
    final base = a.currentPrice;

    int leverage = 0;
    int customAmount = 0;
    if (_custom.text.isNotEmpty) {
      customAmount = int.tryParse(_custom.text) ?? 0;
    }
    final amount = customAmount > base ? customAmount : 0;

    int maxLev = 0;
    int fee = 0;
    int cashNeeded = 0;
    int interest = 0;
    if (amount > 0) {
      maxLev = maxLeverage(data.balance, amount, ctl.netDailyIncomeForUi(state));
      leverage = maxLev.clamp(0, (amount * data.balance.leverageMaxPct / 100).floor()).toInt();
      fee = auctionFee(data.balance, amount,
          reductionPct: ctl.researchValueForUi('auction_fee_reduction_pct'));
      cashNeeded = fee + (amount - leverage);
      interest = leverageWeeklyInterest(data.balance, leverage);
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(i18n.t('ui.app.bid_sheet_title'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          Text(i18n.t(a.target.nameKey)),
          Text('${i18n.t('ui.app.current_price')}: ${money(base)}'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _custom.text = '${(base * 1.05).round()}',
                child: Text(i18n.t('ui.app.bid_plus5')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _custom.text = '${(base * 1.10).round()}',
                child: Text(i18n.t('ui.app.bid_plus10')),
              ),
            ),
          ]),
          TextField(
            controller: _custom,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: i18n.t('ui.app.bid_custom')),
          ),
          const SizedBox(height: 8),
          if (amount > 0) ...[
            Text('${i18n.t('ui.app.fee')}: ${money(fee.round())}'),
            Text('${i18n.t('ui.app.leverage_amount')} (maks ${data.balance.leverageMaxPct.toStringAsFixed(0)}%): ${money(leverage)}'),
            if (leverage > 0)
              Text('${i18n.t('ui.app.leverage_interest')}: ${money(interest)}/w'),
            Text('${i18n.t('ui.app.cash_needed')}: ${money(cashNeeded)}',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: state.tm >= cashNeeded
                    ? () async {
                        await ctl.placeBid(a.id, amount, leverage: leverage);
                        if (context.mounted) Navigator.pop(context);
                      }
                    : null,
                child: Text(i18n.t('ui.app.confirm_bid')),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Sheet rundingan Mega/Legacy: 1 daripada 3 klausa, kesan angka dipaparkan.
class NegotiationSheet extends StatelessWidget {
  final AuctionState auction;
  const NegotiationSheet({super.key, required this.auction});

  @override
  Widget build(BuildContext context) {
    final clauses = auction.clauses ?? generateClauses(auction.seed);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ui.app.negotiation_title',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (var i = 0; i < clauses.length; i++)
            Card(
              child: ListTile(
                title: Text(clauses[i].idKey),
                subtitle: Text(
                    'Harga ${clauses[i].priceAdjPct >= 0 ? '+' : ''}${clauses[i].priceAdjPct.toStringAsFixed(1)}% · Rep ${clauses[i].repDelta >= 0 ? '+' : ''}${clauses[i].repDelta} · Integrasi L${clauses[i].integrationStart}'),
                onTap: () => Navigator.pop(context, i),
              ),
            ),
        ]),
      ),
    );
  }
}
