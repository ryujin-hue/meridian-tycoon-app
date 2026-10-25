/// Ringkasan Semalaman (aliran sesi GDD): pendapatan offline, lelongan selesai,
/// pergerakan CEO saingan, satu berita pasar, butang Collect.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/i18n.dart';
import '../../state/game_controller.dart';
import '../common.dart';

class OvernightSheet extends ConsumerWidget {
  final OvernightSummary summary;
  const OvernightSheet({super.key, required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider);
    final ctl = ref.read(gameControllerProvider.notifier);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(i18n.t('ui.app.overnight_title'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          // Pendapatan offline.
          Row(children: [
            const Icon(Icons.nights_stay, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(i18n.t('ui.app.offline_income'))),
            Text('+${money(summary.offlineIncome)}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ]),
          if (summary.offlineCappedHours >= 8)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(i18n.t('ui.app.offline_capped', {'h': summary.offlineCappedHours}),
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          if (summary.clockRolledBack)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(i18n.t('ui.app.clock_rollback'),
                  style: const TextStyle(fontSize: 12, color: Colors.orange)),
            ),
          const Divider(height: 24),
          // Lelongan selesai.
          if (summary.finishedAuctions.isNotEmpty) ...[
            Text(i18n.t('ui.app.auction_result'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            for (final f in summary.finishedAuctions.take(3))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(f.won ? Icons.emoji_events : Icons.close,
                    color: f.won ? Colors.amber : Colors.grey),
                title: Text(i18n.t(f.nameKey)),
                subtitle: Text(f.won
                    ? i18n.t('ui.app.auction_won_msg')
                    : '${i18n.t('ui.app.winner')}: ${f.winnerCeoId == null ? i18n.t('ui.app.no_bidder') : i18n.t(f.winnerCeoId!)}'),
                trailing: Text(money(f.finalPrice)),
              ),
            const Divider(height: 24),
          ],
          // Pergerakan CEO saingan.
          Text(i18n.t('ui.app.rival_moves'),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          ...summary.rivalMoves.map((m) {
            final parts = m.split(':');
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(child: Text(i18n.t(parts[0]), overflow: TextOverflow.ellipsis)),
                Text(parts.length > 1 ? parts[1] : '',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
            );
          }),
          // Berita pasar.
          if (summary.newsTitleKey != null) ...[
            const Divider(height: 24),
            Row(children: [
              const Icon(Icons.newspaper, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(i18n.t(summary.newsTitleKey!))),
            ]),
          ],
          const SizedBox(height: 16),
          // Butang Collect (satu ketukan).
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                await ctl.collect();
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.monetization_on),
              label: Text(i18n.t('ui.app.collect')),
            ),
          ),
        ]),
      ),
    );
  }
}
