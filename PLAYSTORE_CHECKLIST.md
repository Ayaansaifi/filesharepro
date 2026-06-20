# FileShare Pro — Play Store Production Checklist

## Before upload
- [ ] Replace `ADMOB_APP_ID` and `ADMOB_BANNER_ID` via `--dart-define` or update `AppConstants`
- [ ] Host `privacy_policy/index.html` and `terms_and_conditions/index.html` on a public HTTPS URL
- [ ] Fill **Data safety** form: No data collected to developer server; AdMob disclosed
- [ ] Add **Privacy policy URL** in Play Console
- [ ] Test on Android 10, 13, 14 (permissions + vault + nearby)
- [ ] Remove/disable test AdMob IDs in release build

## Build release APK/AAB
```bash
flutter build appbundle --release \
  --dart-define=ADMOB_APP_ID=ca-app-pub-XXXX~YYYY \
  --dart-define=ADMOB_BANNER_ID=ca-app-pub-XXXX/ZZZZ
```

## Run web UI preview (Chrome)
```bash
run_web.bat
```
Or:
```bash
flutter pub get
flutter run -d chrome --target=lib/main_web.dart --web-port=7357
```

## Data Safety (Google Play) — suggested answers
- **Data collected:** No (developer server). AdMob may collect ad IDs (disclosed under Third-party).
- **Data shared:** None by app; AdMob per Google policy.
- **Encryption:** Vault AES-256 local; P2P transfers optional PIN.
- **Account deletion:** Uninstall / clear app data.

## ASO Keywords
See `ASO_KEYWORDS.md` for 100 Play Store keywords and listing tips.
