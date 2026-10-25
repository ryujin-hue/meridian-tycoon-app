# DECISIONS.md — Keputusan Reka Bentuk (App)

Setiap tafsiran spesifikasi yang dibuat oleh pembangun app direkodkan di sini.
Nombor ekonomi TIDAK dikodkan keras — semua datang dari repo data
(`ryujin-hue/meridian-tycoon-data`). Kecuali yang dinyatakan, keputusan di bawah
adalah mekanik penjadualan/tafsiran UI, bukan angka ekonomi.

## D1 — Sumber kebenaran & pemuatan
- `DATA_BASE_URL = https://raw.githubusercontent.com/ryujin-hue/meridian-tycoon-data/<DATA_REF>/game-data/`
  dengan `DATA_REF = "main"` (boleh ditukar kepada tag di `lib/app/config.dart`).
- Repo data TIADA `manifest.json` → loader memakai mod fallback: bandingkan
  `dataVersion` setiap fail + ETag/If-None-Match. Direkodkan juga dalam `DATA_ISSUES.md`.
- Snapshot bundled dikomit (`assets/data/`) supaya CI tidak memuat turun semasa binaan
  dan game berfungsi penuh offline selepas pemasangan.

## D2 — Julat anggaran nilai sasaran (Peraturan E)
- Nilai dipaparkan sebagai **julat ±8% di sekitar NT**, deterministik: offset
  diterbitkan daripada hash `companyId` (mulberry32 seeded oleh id), jadi julat
  sama setiap kali kad dilukis semula. `ntValue` sebenar hanya didedahkan oleh
  kemahiran CTO `market_scan` selama 24 jam (durasi +6j per stage `market_scan_duration_hours`).

## D3 — Refresh mid-market (Peraturan E)
- Data repo tidak mempunyai jadual refresh. Masa refresh 8 jam dan bilangan
  3–5 sasaran segar adalah **penjadualan, bukan nombor ekonomi**; bilangan
  spesifik per refresh dipilih secara deterministik daripada RNG berbenih
  harian. Kategori: `starter` (t1), `midmarket` (t2–t3), `rare` (t4–t5),
  `mega` (t6–t8), `legacy` — mengikut medan `category` dalam companies.json.

## D4 — Lelongan Mega/Legacy: dua pusingan + rundingan (Peraturan F)
- Round 1 & 2: setiap satu sepanjang `auctionDurationHours` (8j dari data).
  Round 2 bermula serta-merta selepas round 1 dengan harga = harga terakhir round 1.
- Selepas menang round 2 (mega/legacy sahaja): **rundingan 1-daripada-3 klausa**,
  kesan angka dipaparkan sebelum sahkan. Klausa dijana deterministik daripada
  seed lelongan dengan templat: (a) tambahan harga +% → reputasi +, (b) jangka
  integrasi mula lebih tinggi → kos lebih, (c) bayaran penuh tunai (tiada leverage
  kekal) → yuran faedah dihapuskan.

## D5 — Simulasi saingan deterministik (Peraturan F)
- Semasa lelongan dicipta: setiap CEO AI berminat diberi **siling**
  `ntValue × (1 + maxPremiumOverNT)`, disesuaikan profil (aggression, favoriteSectors,
  reputation sasaran) dan pre-seeded jitter; masa masuk = `entryDelayMinutes`
  (±jitter), kenaikan = `bidIncrementPct`. Semua rawak dikunci pada masa penciptaan
  (seed disimpan dalam lelongan), dan lelongan diproses **langkah tetap 5 minit**
  daripada `processedUntil` → "sekarang". Maka hasil offline ≡ dimainkan langsung.
- Bidaan pemain: preset +5% / +10% atau jumlah tersuai; yuran `%` setiap bidaan
  pemain didebit serta-merta (reduksi research `auction_fee_reduction_pct`;
  lantai 1.2% terhasil daripada hardCap data, bukan kod).
- Leverage sehingga `leverageMaxPct` daripada harga, had
  `leverageCapDailyNetMultiplier × pendapatan harian bersih`, faedah
  `leverageInterestWeeklyPct` seminggu atas baki. Skrin sahkan memaparkan tunai
  diperlukan + leverage + yuran sebelum sahkan.

## D6 — Sumbangan syarikat & integration level (Peraturan G)
- Sumbangan bersih = `grossIncomePerHourK × 1000 × purchasedCompanyNetContributionPct%`
  × (1 + 0.10 × (integrationLevel − 1)), integrationLevel 1–5 (dinaik taraf dengan DP
  melalui tindakan TM/DP "Integration" pada kad portfolio: kos = 25% NT semasa × level).
- Penunjuk prestasi minguan: skor = sumbangan sebenar minggu vs jangkaan payback data;
  cadangan tindakan (Invest/Restructure/Hold) deterministik daripada trend skor + rng berbenih.

## D7 — Hutang (Peraturan H)
- Bayaran balik automatik 25% daripada setiap Collect (25 = `debtAutoRepayPct`
  dalam config app — nombor penjadualan peraturan GDD H, bukan dari data);
  faedah mingguan = `leverageInterestWeeklyPct` atas baki pokok (dari data);
  tiada pemulihan paksa.

## D8 — Pitch pelabur (Peraturan I)
- Kebarangkalian = clamp(0.30 + 0.006 × reputasi + modifier sudut, 0.30, 0.90).
  Modifier sudut: Growth +0.05 (liputan operasi ≥ 100% sasaran), Safety +0.05
  (baki hutang = 0), Story +0.05 (memiliki ≥1 legacy). Cooldown 24 jam.
- Ganjaran DP ikut tier: `10 × tier` (tiada jadual pitch dalam data — keputusan
  reka bentuk, dijana daripada tiers.json `tier` indeks).
- Slot: mula 1, +1 setiap 6 milestone selesai (maksimum 4).

## D9 — Naik Tier (Peraturan J)
- Tiga meter: **Kapasiti** = slot operasi terisi penuh pada tier semasa
  (count(ops) ≥ tier.maxOperations); **Reputasi** ≥ `reputationThreshold` tier sasaran;
  **Modal** = net worth (tunai + Σ NT syarikat dimiliki) ≥ `baseValueA` tier sasaran.
  Tambahan: memiliki ≥1 syarikat tier sasaran. Ganjaran dipaparkan
  (`tierUpRewardDP`, `rewardKey`) sebelum "Sahkan" → Tier-Up Cinematic.

## D10 — LiveOps tanpa server (Peraturan L)
- Anchor epoch tetap: `2026-01-05T00:00:00Z` (Isnin) dalam `lib/app/config.dart`.
  Hari = UTC; minggu reset Isnin UTC; musim = 6 minggu (`weeksPerSeason` data);
  bulan = kalendar UTC. Progression musim = skor minguan terkumpul; trek premium
  hanya kosmetik/keselesaan (dipatuhi data).
- Mingguan: 1 sasaran minguan (`weekly_target`), 1 Habis Stok 48 jam (`stock_out`
  dipilih seeded minguan), 1 Perang Bidaan (`bidding_war` dijadualkan dalam minggu).
- Harian: 1 kontrak harian (`daily_contract` ikut tierBand). Bulanan: sasaran
  kumulatif kontrak bulan itu. Ganjaran event sampingan sahaja.

## D11 — Leaderboard pocket league (Peraturan M)
- 30 pemain (pemain + 29 bot). Skor pemain = pendapatan bersih dikutip minggu ini
  + bonus menang lelongan (NT sasaran ÷ 1000). Bot = `weeklyScoreBase ± variance`
  (seed minguan). Reset Isnin UTC. 120 nama namePool untuk penggantian.

## D12 — Offline (Peraturan B)
- `offlineCapHours` dari data; dinaikkan melalui research `offline_cap_hours`
  (hardCap data 12j). Jam diundur → 0 pendapatan offline untuk sesi itu + log
  (`lastSeenAt > now`). Lonjakan ke hadapan dihadkan kepada had simpanan.

## D13 — Gaji & sinergi kecil (Peraturan C)
- Gaji harian = `salaryByTier[tier]` setiap staf, didebit SEKALI sehari semasa
  Collect (`lastSalaryDebitDay`). Kos ambil = `2500 × star × hireTierScale[tier]`.
- Sinergi kecil (reka bentuk): staf yang sektor kegemaran pemain sama dengan
  sektor operasi memberi +1% pendapatan operasi setiap pasangan (had +5%);
  syarikat `synergySector` sepadan dengan sektor operasi memberi +2% (had +6%).

## D14 — Rive & Lottie
- Tiada fail `.riv` berlesen tersedia → `AnimationRegistry` dengan fallback
  Flutter/Flame penuh (app berfungsi 100% tanpa .riv) + TODO di docs/ASSETS.md.
- Lottie dijana oleh `tool/gen_lottie.py` (syiling, konfeti, lencana, kalah lembut)
  — buatan sendiri, tiada lesen pihak ketiga.

## D15 — Notifikasi (Android 13+)
- Hanya keputusan: lelongan tamat (menang/kalah/outbid) + pelabur menjawab,
  kunci `notif.*` dari data i18n. Maksimum 2 sehari (kaunter dalam save),
  pemasaran mati lalai, tiada alarm tepat (guna inexact + pengiraan semasa app dibuka).

## D16 — Kamera/pendawaian Flame
- Adegan Flame MEMBACA state (melalui provider) dan menghantar perintah
  MELALUI GameController sahaja (aliran satu hala). Had ~200 komponen;
  tiada alokasi setiap frame (pool objek); enjin dijeda app di latar belakang.
- "Reduce motion" mematikan Lottie, Rive dan zarah Flame serta-merta.

## D17 — Tutorial
- 10 langkah daripada tutorial.json dengan spotlight; `starterTarget` BERSKRIP:
  lelongan T1 termurah tanpa bida AI selama `noAiBidsMinutes`, sasaran harga
  `maxStartPriceTM`; `starterGrant.tm` diberi pada langkah 1. Pembelian pertama
  disasarkan dalam 8 minit (`firstPurchaseWithinMinutes`).

## D18 — 2-tap rule
- Bottom navigation tetap (5 tab) + bar tindakan pantas yang sama pada semua
  tab (Kutip, Bida/Pasar, Naik Tier) — semua tindakan utama ≤ 2 ketukan.
