# Meridian Tycoon (App)

Game tycoon F2P Flutter: anda ialah CEO yang bermula dengan satu operasi kecil dan
naik **8 tier syarikat** dengan membeli syarikat melalui **lelongan masa nyata**.
Sesi 5–15 minit, 2–4 kali sehari. Pendapatan offline, tiada energy, tiada tembok
berbayar, tiada iklan, tiada loot box.

**Repo data:** [ryujin-hue/meridian-tycoon-data](https://github.com/ryujin-hue/meridian-tycoon-data)
(app ini HANYA memuatkan data; ia tidak menjana atau mengubah data).

## Teknologi

| Lapisan | Teknologi | Peranan |
|---|---|---|
| UI | Flutter (Material 3) | Menu, senarai, dialog, bottom sheet |
| Adegan | Flame (`GameWidget`) | 4 adegan prosedur: HQ Diorama, City Skyline, Auction Room, Tier-Up Cinematic |
| Animasi sekali-main | Lottie | Syiling, konfeti, lencana naik tier, kalah lembut |
| State-machine | Rive (fallback Flutter/Flame) | Avatar CEO, tukul lelongan, butang Kutip |
| State | flutter_riverpod | `GameState` tak berubah + `GameController` |

## Bina dari sumber

```bash
flutter pub get
flutter test          # unit + widget
flutter analyze
flutter build apk --release --split-per-abi
```

Data bundled disalin oleh `tool/sync_data.sh` ke `assets/data/` (snapshot
dikomit, jadi game berfungsi penuh tanpa internet selepas pemasangan).
Kemas kini data remote: maksimum sekali setiap 6 jam, timeout 5 saat,
tidak pernah menyekat permulaan game; dipakai pada permulaan app seterusnya.

## Struktur

```
lib/{app,domain,data,state,ui,game}/   app: config/tema/i18n · domain: Dart tulen 100% boleh uji
                                       data: pemuat/cache/save · state: Riverpod · ui: skrin · game: adegan Flame
assets/{data,i18n_app,lottie,rive}/    data bundled · teks app 3 bahasa · animasi · slot .riv
tool/                                  sim.dart (bot 60 hari), sync_data.sh, gen_lottie.py
docs/                                  DECISIONS, ASSETS, DATA_ISSUES, HOW_TO_PLAY, ECONOMY_SIM
test/                                  unit domain + pemuat data (fake HTTP) + widget
```

## CI/CD

- `.github/workflows/build.yml` — setiap push/PR: `pub get`, `analyze`, `test`, `build apk debug`, artifact.
- `.github/workflows/release.yml` — push ke `main` / tag `v*`: bina release split-per-abi + APK universal,
  ditandatangani jika secret keystore wujud (`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`),
  jika tidak guna tandatangan debug supaya APK tetap boleh dipasang. Nota rilis daripada commit; terbit ke GitHub Releases.

## Lesen

MIT — lihat [LICENSE](LICENSE).
