# DATA_ISSUES.md — Ketidaksepadanan Data & Penyelesaian Sementara

Prinsip: repo data TIDAK diubah oleh app. Ketidaksepadanan diceritakan di sini
dan diselesaikan sementara dalam loader. Dikemas kini semasa debug.

| Tarikh | Isu | Kesan | Penyelesaian sementara dalam loader |
|---|---|---|---|
| 2026-10-25 | Tiada `manifest.json` (versi, senarai fail, sha256) dalam `game-data/` | Kemas kini remote tidak boleh disahkan sekali gus | Mod fallback: setiap fail disemak `dataVersion` + ETag/If-None-Match; keseluruhan set dimuat turun ke folder sementara, disahkan (JSON sah, fail wajib 16, major version serasi, pariti kunci i18n 3 bahasa, julat selamat), kemudian tukar atomik |
| 2026-10-25 | Jadual refresh mid-market (3–5 sasaran / 8 jam) tiada dalam fail data | Tidak boleh dibaca dari data | Penjadualan dalam `lib/app/config.dart` (bukan nombor ekonomi); bilangan spesifik daripada RNG berbenih — lihat DECISIONS.md D3 |
| 2026-10-25 | Jadual ganjaran DP pitch per tier tiada dalam data | Pitch memerlukan ganjaran DP | Formula `10 × tier` daripada tiers.json — DECISIONS.md D8 |
| 2026-10-25 | Medan `tier` companies.json ialah integer (1–8), tiada `tierId` string | Perbezaan tangga | Loader menormalkan kepada indeks 0–7 |
| 2026-10-25 | `bidding_war` tiada senarai CEO; `extraCompetitorCount` + `aggressionBoostPct` sahaja | Perlu pilih CEO tambahan | CEO tambahan dipilih deterministik daripada seed lelongan (pool ai_ceos.json) |
| 2026-10-25 | `daily_contract.goal.type` pelbagai (cth `collect_income`) dan `reward` bercampur TM/DP | Enjin kesan generik perlu menyokong jenis ini | Enjin kesan membaca peta `effect`/`goal`/`reward` secara generik (add_currency, rep, multiplier, unlock_slot, cosmetic) |
| 2026-10-25 | Kunci `ui.*` sudah wujud dalam i18n data (btn/currency/label/msg) | Risiko pelanggaran kunci dengan teks app | Teks app khusus guna awalan `ui.app.*` dalam `assets/i18n_app/{en,ms,id}.json`; merge: data dahulu, app menang pada kunci sendiri |
