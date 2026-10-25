/// Widget biasa: format mata wang (intl), kad, meter, lencana.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app/i18n.dart';
import '../app/theme.dart';
import '../state/game_controller.dart';

final NumberFormat _compact = NumberFormat.compact();
final NumberFormat _full = NumberFormat.decimalPattern('en');

String money(int v) => _full.format(v);
String moneyCompact(int v) => _compact.format(v);

/// Warna sektor daripada data melalui provider.
class MeridianSectorColor {
  static Color of(WidgetRef ref, String sectorId) {
    final data = ref.watch(gameDataProvider);
    return MeridianTheme.sectorColor(data, sectorId);
  }
}

class StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const StatChip({super.key, required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const SectionCard({super.key, required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: padding, child: child));
  }
}

/// Meter naik tier — maklumat TIDAK bergantung warna sahaja (label + nilai).
class MeterBar extends StatelessWidget {
  final String label;
  final double value;
  final double target;
  final String valueText;
  final I18n i18n;
  const MeterBar({
    super.key,
    required this.label,
    required this.value,
    required this.target,
    required this.valueText,
    required this.i18n,
  });

  @override
  Widget build(BuildContext context) {
    final ok = value >= target;
    final frac = target <= 0 ? 1.0 : (value / target).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18, color: ok ? Colors.green : null,
              semanticLabel: ok ? 'ok' : 'pending'),
          const SizedBox(width: 6),
          Expanded(child: Text(label)),
          Text(valueText, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: frac, minHeight: 6,
              semanticsLabel: '$label ${moneyCompact(value.round())}/${moneyCompact(target.round())}'),
        ),
      ]),
    );
  }
}
