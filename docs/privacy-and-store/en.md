# Hydration Universe — English store and privacy draft

**Short description:** Offline water intake log with a daily total.

**Description:** Record water intake in milliliters, review today's total and delete entries. The interface includes English, Turkish and Arabic resources.

## Data handling — current MVP
- Water amount and timestamp are persisted locally using shared_preferences without encryption.
- No account, cloud sync, analytics, ads or network transmission is implemented.
- Individual entry deletion exists; delete-all, export and secure backup are not yet implemented.
- This is a personal log, not a medical device or individualized hydration recommendation.

## Release blockers
Verify Android/iOS backup behavior, RTL, numeric localization, accessible controls, data erasure, store labels and regional privacy notices before publication. This draft is **not** a final legal privacy policy.
