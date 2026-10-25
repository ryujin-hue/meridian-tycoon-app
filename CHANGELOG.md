# Perubahan

## [0.1.0] — 2026-10-25

### Ditambah
- Fasa 0: scaffold Flutter, CI build + release workflow, snapshot data bundled (tool/sync_data.sh).
- Fasa 1: domain tulen — ekonomi NT, lelongan deterministik, leverage, hutang, offline, tier, pitch, staf, research, effects, LiveOps, leaderboard.
- Fasa 2: pemuat data 3 lapisan (bundled/cache/remote), save berversi + snapshot, state Riverpod, shell 5 tab, tema M3, i18n 3 bahasa.
- Fasa 3: Markas, operasi, offline, Kutip Semua + HQ Diorama (Flame).
- Fasa 4: Pasar, lelongan 2 pusingan + rundingan, saingan AI, leverage, Naik Tier + Auction Room + Tier-Up cinematic.
- Fasa 5: Staf, research, pitch pelabur, LiveOps, leaderboard pocket league, portfolio.
- Fasa 6: Tutorial 10 langkah, Lottie/Rive (fallback), Settings, notifikasi tempatan, kebolehcapaian, prestasi.
- Fasa 7: sim 60 hari (docs/ECONOMY_SIM.md), README, Release v0.1.0.

### Dibaiki
- Model bidaan: yuran didebit semasa bida; harga dibayar semasa menang (tanpa eskro).
- Boss AI hanya menyertai lelongan legacy; minat CEO mengikut aggression.
- Core library desugaring untuk flutter_local_notifications; locale ms/id penuh.
