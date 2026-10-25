# ECONOMY_SIM — Simulasi 60 Hari (dijana oleh tool/sim.dart)

Bot: 2 sesi sehari, strategi mudah (kutip, naik taraf, bida termurah).
Data: v1.0.0 (snapshot bundled). Deterministik (seed tetap).

## Hari mencapai setiap tier

| Tier | Hari |
|---|---|
| T1 | 0 |
| T2 | — (tidak dicapai) |
| T3 | — (tidak dicapai) |
| T4 | — (tidak dicapai) |
| T5 | — (tidak dicapai) |
| T6 | — (tidak dicapai) |
| T7 | — (tidak dicapai) |
| T8 | — (tidak dicapai) |

## Syarikat diperoleh & payback sebenar (dari data)

| Hari | Syarikat | Harga akhir | Payback data (hari) |
|---|---|---|---|
| 0 | T1 co_fnb_t1_01 | 36561 | 22.9 |
| 30 | T1 co_fnb_t1_06 | 60901 | 25.0 |

## Semakan sisihan

- Sasaran dalam data: T1 payback 15-25 hari; T2-4 10-20; T5 20-40.
- Syarikat di luar band payback: 0 daripada 2 (harga menang ialah bidaan pemain; payback dikira daripada harga akhir).
- Tier 8 TIDAK dicapai dalam 60 hari dengan strategi mudah ini (sasaran reka bentuk: sesi 5-15 minit, bukan speedrun).
## Penemuan (dari larian ini)

- Pembelian pertama: hari 0 melalui sasaran berskrip tutorial
  (tiada bida AI dalam 8 minit) — sasaran
  "pembelian pertama dalam 8 minit" dipatuhi.
- Kemenangan T1 kekal dalam band payback apabila bot membida pada
  siling band (25 hari) — AI premium (maxPremiumOverNT 0.2-0.35)
  kerap menewaskan bidaan di bawah ~1.2x NT.
- Ketegangan direkod: minat CEO kegemaran sektor (~95%) mendorong
  harga menang ke ~1.2-1.36x NT, manakala band T2-4 (10-20 hari)
  menyekat harga ke ~1.1-1.2x NT — kemenangan T2-4 dalam band menjadi
  jarang. DILAPORKAN kepada repo data; data TIDAK diubah.

Keputusan ini melaporkan; data TIDAK diubah (Peraturan sim).

