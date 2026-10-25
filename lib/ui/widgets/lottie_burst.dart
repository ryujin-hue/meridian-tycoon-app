/// Overlay Lottie sekali-main (syiling/konfeti/lencana/kalah lembut).
/// "Reduce motion" mematikan sepenuhnya (Peraturan kebolehcapaian).
/// Fail .json dijana oleh tool/gen_lottie.py (docs/ASSETS.md).
library;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

enum BurstKind { coin, confetti, badgeUp, softLose }

class LottieBurst extends StatefulWidget {
  final BurstKind kind;
  final bool enabled; // false = Reduce Motion
  final VoidCallback? onDone;
  const LottieBurst({super.key, required this.kind, required this.enabled, this.onDone});

  @override
  State<LottieBurst> createState() => _LottieBurstState();
}

class _LottieBurstState extends State<LottieBurst> {
  bool _shown = false;

  @override
  void didUpdateWidget(covariant LottieBurst old) {
    super.didUpdateWidget(old);
    if (widget.enabled && !_shown) {
      _shown = true;
      setState(() {});
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() => _shown = widget.enabled && false);
          widget.onDone?.call();
        }
      });
    }
  }

  String get _asset => switch (widget.kind) {
        BurstKind.coin => 'assets/lottie/coin.json',
        BurstKind.confetti => 'assets/lottie/confetti.json',
        BurstKind.badgeUp => 'assets/lottie/badge_up.json',
        BurstKind.softLose => 'assets/lottie/soft_lose.json',
      };

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || !_shown) return const SizedBox.shrink();
    return IgnorePointer(
      child: Center(
        child: Lottie.asset(
          _asset,
          width: 180,
          height: 180,
          repeat: false,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _shown = widget.enabled;
  }
}

/// Hos burst: tukar [trigger] untuk mainkan sekali.
class BurstHost extends StatelessWidget {
  final int trigger;
  final bool enabled;
  final BurstKind kind;
  const BurstHost({super.key, required this.trigger, required this.enabled, this.kind = BurstKind.coin});

  @override
  Widget build(BuildContext context) {
    return _BurstInner(key: ValueKey(trigger), enabled: enabled, kind: kind);
  }
}

class _BurstInner extends StatefulWidget {
  final bool enabled;
  final BurstKind kind;
  const _BurstInner({super.key, required this.enabled, required this.kind});

  @override
  State<_BurstInner> createState() => _BurstInnerState();
}

class _BurstInnerState extends State<_BurstInner> {
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _playing = true;
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _playing = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_playing) return const SizedBox.shrink();
    return IgnorePointer(
      child: Center(
        child: Lottie.asset(
          widget.kind == BurstKind.coin
              ? 'assets/lottie/coin.json'
              : widget.kind == BurstKind.confetti
                  ? 'assets/lottie/confetti.json'
                  : widget.kind == BurstKind.badgeUp
                      ? 'assets/lottie/badge_up.json'
                      : 'assets/lottie/soft_lose.json',
          width: 200,
          height: 200,
          repeat: false,
        ),
      ),
    );
  }
}
