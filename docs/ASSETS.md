# ASSETS.md — Sumber & Lesen Aset

Prinsip: hanya aset yang dicipta sendiri atau berlesen yang membenarkan
pengagihan dalam app komersial. Tiada aset berlesen pihak ketiga digunakan.

| Aset | Jenis | Sumber | Lesen |
|---|---|---|---|
| `assets/lottie/coin.json` | Lottie (sekali-main) | Dijana oleh `tool/gen_lottie.py` (buatan sendiri, prosedur) | MIT (repo ini) |
| `assets/lottie/confetti.json` | Lottie | `tool/gen_lottie.py` | MIT (repo ini) |
| `assets/lottie/badge_up.json` | Lottie | `tool/gen_lottie.py` | MIT (repo ini) |
| `assets/lottie/soft_lose.json` | Lottie | `tool/gen_lottie.py` | MIT (repo ini) |
| Adegan Flame (HQ Diorama, City Skyline, Auction Room, Tier-Up) | Vektor prosedur (Canvas) | Dilukis secara programatik dalam `lib/game/` — tiada sprite | MIT (repo ini) |
| Rive | `.riv` | TIADA fail — `AnimationRegistry` fallback Flutter/Flame; TODO: gantikan dengan .riv buatan sendiri jika tersedia | — |
| Ikon app | PNG launcher | Dijana (PIL) daripada logo vektor buatan sendiri | MIT (repo ini) |
| Fon | Roboto | Dibundel Android secara lalai (Apache 2.0) | Apache 2.0 |

TODO(Rive): cipta state-machine avatar CEO (tenang/tegang/menang/kalah), tukul
lelongan dan butang Kutip Semua dalam Rive; daftar dalam `AnimationRegistry`
(`lib/game/animation_registry.dart`). Fallback animasi Flutter/Flame sentiasa aktif.

Data game (fail JSON, teks, berita) adalah milik repo data
`ryujin-hue/meridian-tycoon-data` dan dimuatkan, bukan dijana semula.
