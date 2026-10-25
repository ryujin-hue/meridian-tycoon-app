/// AnimationRegistry: Rive state-machine (avatar CEO, tukul, butang Kutip)
/// dengan FALLBACK Flutter/Flame penuh — app berfungsi 100% tanpa fail .riv.
/// TODO(assets): cipta .riv buatan sendiri (docs/ASSETS.md) dan daftar di sini.
library;

import 'package:flutter/material.dart';

/// Keadaan avatar CEO (state-machine Rive yang dimiripkan).
enum CeoMood { calm, tense, winning, losing }

/// Rekod animasi: nama, sumber .riv (jika ada), fallback builder.
class AnimationEntry {
  final String name;
  final String? rivAsset; // null → fallback sentiasa
  final WidgetBuilder fallback;
  const AnimationEntry(this.name, this.rivAsset, this.fallback);
}

/// Registry global. `Reduce motion` → UI memaklumi melalui [enabled]=false.
class AnimationRegistry {
  final bool enabled; // false apabila Reduce Motion
  AnimationRegistry({this.enabled = true});

  /// TODO(rive): ganti rivAsset bila .riv tersedia.
  static const Map<String, String?> _rivAssets = {
    'ceo_avatar': null, // state-machine: calm/tense/winning/losing
    'auction_hammer': null,
    'collect_button': null,
  };

  bool hasRive(String name) => enabled && (_rivAssets[name] != null);

  /// Widget untuk nama animasi; fallback sentiasa berfungsi.
  Widget build(String name, CeoMood mood) {
    // Fallback ikonik — stabil, tiada aset diperlukan.
    final icon = switch (mood) {
      CeoMood.calm => Icons.self_improvement,
      CeoMood.tense => Icons.psychology,
      CeoMood.winning => Icons.emoji_events,
      CeoMood.losing => Icons.sentiment_dissatisfied,
    };
    return Icon(icon, size: 28,
        semanticLabel: 'ceo_$name:${mood.name}');
  }

  /// Tukul lelongan (fallback animasi scale ringkas via AnimatedScale di UI).
  Widget hammer({VoidCallback? onTap}) {
    return IconButton(
      onPressed: enabled ? onTap : null,
      icon: const Icon(Icons.gavel),
      tooltip: 'bid',
    );
  }
}
