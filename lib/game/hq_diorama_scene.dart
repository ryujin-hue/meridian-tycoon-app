/// HQ Diorama (Flame): bangunan potret, bilik operasi menyala ikut tahap,
/// staf, syiling melambung apabila kutip. Dilukis prosedur (tiada sprite).
/// MEMBACA state; perintah melalui controller sahaja (aliran satu hala).
library;

import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Colors;

import '../data/models.dart';
import '../state/game_state.dart';

class HqDioramaGame extends FlameGame {
  final GameData data;
  final GameState? Function() readState;
  final bool reduceMotion;

  final _rooms = <PositionComponent>[];
  final _roomPaints = <Paint>[];
  final _coinPool = <RectangleComponent>[];
  double _t = 0;

  HqDioramaGame(this.data, this.readState, {this.reduceMotion = false});

  @override
  Future<void> onLoad() async {
    // Bangunan prosedur: tonggak + bumbung + bilik ikut maxOperations tier.
    final tower = RectangleComponent(
      position: Vector2(size.x * 0.32, size.y * 0.18),
      size: Vector2(size.x * 0.36, size.y * 0.72),
      paint: Paint()..color = const Color(0xFF22304A),
    );
    add(tower);
    final roof = PolygonComponent(
      [
        Vector2(tower.x - 6, tower.y),
        Vector2(tower.x + tower.width + 6, tower.y),
        Vector2(tower.x + tower.width / 2, tower.y - 26),
      ],
      paint: Paint()..color = const Color(0xFF35507A),
    );
    add(roof);
    // Bilik: grid mengikut slot operasi tier semasa (menyala ikut tahap).
    final tier = data.tiers[readState()?.tierIndex0 ?? 0];
    final cols = 2;
    for (var i = 0; i < tier.maxOperations.clamp(1, 12); i++) {
      final c = i % cols;
      final r = i ~/ cols;
      final p = Paint()..color = const Color(0xFF101826);
      final room = RectangleComponent(
        position: Vector2(
          tower.x + 8 + c * (tower.width - 16 - 14) / cols + c * 4,
          tower.y + 14 + r * 22,
        ),
        size: Vector2((tower.width - 16 - 14) / cols, 16),
        paint: p,
      );
      room.add(RectangleComponent(
        size: Vector2(4, 4),
        position: Vector2(4, 6),
        paint: Paint()..color = const Color(0xFF3A4B66),
      ));
      tower.add(room);
      _rooms.add(room);
      _roomPaints.add(p);
    }
    // Pool syiling (tiada alokasi setiap frame).
    for (var i = 0; i < 12; i++) {
      final coin = RectangleComponent(
        size: Vector2(8, 8),
        paint: Paint()..color = const Color(0xFFFFC95C),
        position: Vector2(-20, -20),
      );
      coin.addToParent(this);
      coin.priority = 10;
      _coinPool.add(coin);
    }
    // Label kemudahan.
    add(TextComponent(
      text: 'T${(readState()?.tierIndex0 ?? 0) + 1}',
      position: Vector2(size.x - 34, 8),
      textRenderer: TextPaint(
          style: const TextStyle(fontSize: 18, color: Color(0xFF9FB4D8), fontWeight: FontWeight.w700)),
    ));
  }

  /// Syiling melambung semasa kutipan (dipanggil dari UI).
  void burstCoins() {
    if (reduceMotion) return;
    var launched = 0;
    for (final c in _coinPool) {
      if (c.position.x >= 0) continue;
      c.position = Vector2(
        size.x * (0.35 + math.Random().nextDouble() * 0.3),
        size.y * 0.75,
      );
      c.add(MoveEffect.to(
        Vector2(c.position.x + (math.Random().nextDouble() - 0.5) * 40,
            -10),
        EffectController(duration: 0.8, startDelay: launched * 0.05),
        onComplete: () => c.position = Vector2(-20, -20),
      ));
      if (++launched >= 8) break;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (reduceMotion) return;
    // Pengawal: state mungkin tidak tersedia (container dibuang).
    final GameState? st;
    try {
      st = readState();
    } catch (_) {
      return;
    }
    if (st == null) return; // container dibuang — langkau
    // Bilik menyala berdenyut halus (sinus — tiada alokasi).
    for (var i = 0; i < _roomPaints.length && i < st.ops.length; i++) {
      final level = st.ops[i].level;
      final glow = (math.sin(_t * 2 + i) * 0.5 + 0.5) * (0.25 + level * 0.07);
      _roomPaints[i].color = Color.lerp(
          const Color(0xFF101826), const Color(0xFFFFD977), glow.clamp(0.0, 1.0))!;
    }
  }
}
