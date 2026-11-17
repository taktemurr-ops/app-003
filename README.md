# APP-003 — Hydration Universe

Independent offline-first Flutter hydration journal for Android and iOS.

## Implemented initial source
- Log water intake in milliliters; today's total and individual entries.
- Persist, reload, and delete entries with shared_preferences.
- Validate amount range (1–2000 mL) and recover safely from corrupt JSON.
- ARB translations: English (en), Turkish (tr), Arabic (ar); Material RTL layout enabled through Flutter localization.
- Unit tests and GitHub Actions analysis/test workflow.

## Local setup
```sh
flutter create --platforms=android,ios .
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter run
```

Native Android/iOS scaffolding is not committed. Neither Flutter tests nor device builds are verified yet.

## Privacy, safety and roadmap
Entries are stored locally via shared_preferences (not encrypted). Do not use this app for sensitive medical records. No account, advertising, network sync, or telemetry is implemented. Planned: accessible UI audit, locale-aware numeric entry, encrypted backup/export, deletion controls, reminders, goals, consent and regional privacy review, broader language coverage and store localization.

This is not a medical device and does not provide clinical hydration guidance.
