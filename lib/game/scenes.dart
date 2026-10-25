/// City Skyline Pasar (Flame): sasaran lelongan sebagai bangunan berwarna
/// ikut sektor. Prosedur; ~40 komponen (had prestasi dihormati).
library;

import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Colors;

import '../data/models.dart';
import '../state/game_state.dart';

class CitySkylineGame extends FlameGame {
  final GameData data;
  final GameState Function() readState;
  CitySkylineGame(this.data, this.readState);

  @override
  Future<void> onLoad() async {
    final st = readState();
    final targets = st.market.take(9).toList();
    final colors = {
      for (final s in data.sectors) s.id: _parse(s.colorHex),
    };
    final w = size.x / (targets.length + 1);
    for (var i = 0; i < targets.length; i++) {
      final t = targets[i];
      final h = 30.0 + (t.snap.ntValue % 50).toDouble() * 0.9;
      final col = colors[t.snap.sector] ?? const Color(0xFF4C7DF0);
      add(RectangleComponent(
        position: Vector2(w * (i + 0.5) + 4, size.y - h),
        size: Vector2(w - 8, h),
        paint: Paint()..color = col.withValues(alpha: 0.75),
      ));
      // Tingkap (2 titik sahaja per bangunan — murah).
      add(RectangleComponent(
        position: Vector2(w * (i + 0.5) + w / 2 - 3, size.y - h * 0.6),
        size: Vector2(4, 4),
        paint: Paint()..color = const Color(0xFFFFE9A8),
      ));
    }
  }

  static Color _parse(String hex) {
    final v = hex.replaceFirst('#', '');
    try {
      return Color(int.parse('FF$v', radix: 16));
    } catch (_) {
      return const Color(0xFF4C7DF0);
    }
  }
}

/// Auction Room (Flame): podium, avatar CEO saingan dengan gelembung bidaan,
/// harga, pemasa. Prosedur.
class AuctionRoomGame extends FlameGame {
  final GameData data;
  final GameState Function() readState;
  final String auctionId;
  final bool reduceMotion;

  TextComponent? _priceLabel;
  TextComponent? _timerLabel;
  int _lastMinute = -1;

  AuctionRoomGame(this.data, this.readState, this.auctionId,
      {this.reduceMotion = false});

  @override
  Future<void> onLoad() async {
    // Podium.
    add(RectangleComponent(
      position: Vector2(size.x * 0.30, size.y * 0.55),
      size: Vector2(size.x * 0.40, size.y * 0.30),
      paint: Paint()..color = const Color(0xFF2A3A57),
    ));
    // Avatar: pemain tengah, AI di kedua-dua belah (maks 6 — had komponen).
    final st = readState();
    final a = st.auctions.firstWhere(
        (x) => x.id == auctionId,
        orElse: () => st.auctions.first);
    final ceoCount = a.bidders.take(6).toList();
    for (var i = 0; i < ceoCount.length + 1; i++) {
      final x = size.x * (0.15 + 0.7 * i / (ceoCount.length));
      final isPlayer = i == ceoCount.length ~/ 1 ~/ 1; // pemain pada kedudukan terakhir
      add(CircleComponent(
        radius: 14,
        position: Vector2(x, size.y * 0.35),
        paint: Paint()
          ..color = isPlayer ? const Color(0xFF46B58A) : const Color(0xFFF09A4C),
      ));
    }
    _priceLabel = TextComponent(
      position: Vector2(size.x / 2 - 40, size.y * 0.60),
      textRenderer: TextPaint(style: const TextStyle(
          fontSize: 20, color: Color(0xFFFFC95C), fontWeight: FontWeight.w800)),
    );
    add(_priceLabel!);
    _timerLabel = TextComponent(
      position: Vector2(size.x / 2 - 30, size.y * 0.78),
      textRenderer: TextPaint(style: const TextStyle(
          fontSize: 14, color: Color(0xFF9FB4D8))),
    );
    add(_timerLabel!);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final st = readState();
    final a = st.auctions.where((x) => x.id == auctionId).firstOrNull;
    if (a == null) return;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 60000;
    if (now != _lastMinute) {
      _lastMinute = now;
      _priceLabel?.text = a.currentPrice.toString();
      final left = (a.endMinute - now).clamp(0, 999999);
      _timerLabel?.text =
          '${left ~/ 60}h ${left % 60}m · ${a.leader == 'player' ? 'YOU' : ''}';
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// Halaman sinematik Naik Tier — boleh dilangkau dengan satu ketukan.
class TierUpCinematicPage extends StatelessWidget {
  final TierCinematicGame game;
  const TierUpCinematicPage({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1420),
      body: GestureDetector(
        onTap: () async => await game.onComplete(),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: double.infinity,
              height: 420,
              child: GameWidget(game: game),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () async => await game.onComplete(),
              child: const Text('SKIP >>',
                  style: TextStyle(color: Color(0xFF9FB4D8))),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Tier-Up Cinematic (Flame): peta empayar mengembang + zarah.
/// Boleh dilangkau dengan satu ketukan (kebolehcapaian).
class TierCinematicGame extends FlameGame {
  final GameData data;
  final int newTierIndex0;
  final bool reduceMotion;
  final Future<void> Function() onComplete;

  double _t = 0;
  bool _done = false;
  final _particles = <CircleComponent>[];

  TierCinematicGame(this.data, this.newTierIndex0,
      {required this.reduceMotion, required this.onComplete});

  @override
  Future<void> onLoad() async {
    // Peta: petak grid yang menyala beransur (empayar mengembang).
    final cols = 6;
    final rows = 4;
    final cellW = size.x / cols;
    final cellH = size.y * 0.7 / rows;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final cell = RectangleComponent(
          position: Vector2(c * cellW + 2, size.y * 0.1 + r * cellH + 2),
          size: Vector2(cellW - 4, cellH - 4),
          paint: Paint()..color = const Color(0xFF18202F),
        );
        cell.add(RectangleComponent(
          size: Vector2(cellW - 12, cellH - 12),
          position: Vector2(4, 4),
          paint: Paint()..color = const Color(0xFF22314E),
        ));
        add(cell);
      }
    }
    add(TextComponent(
      text: 'TIER ${newTierIndex0 + 1}',
      position: Vector2(size.x / 2 - 44, size.y * 0.84),
      textRenderer: TextPaint(style: const TextStyle(
          fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFFFFC95C))),
    ));
    if (!reduceMotion) {
      for (var i = 0; i < 30; i++) {
        final p = CircleComponent(
          radius: 1.5 + math.Random().nextDouble() * 2,
          position: Vector2(size.x / 2, size.y / 2),
          paint: Paint()..color = const Color(0xFFFFC95C),
        );
        add(p);
        _particles.add(p);
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (!reduceMotion) {
      for (var i = 0; i < _particles.length; i++) {
        final angle = i / _particles.length * 2 * math.pi;
        final dist = (_t * 60) % (size.x * 0.5);
        _particles[i].position = Vector2(
          size.x / 2 + math.cos(angle) * dist,
          size.y / 2 + math.sin(angle) * dist * 0.6,
        );
      }
    }
    if (!_done && _t > 2.4) {
      _done = true;
      onComplete();
    }
  }
}
