# Personal Cashflow

A clean, private cash book for Android — rebuilt as an original
implementation inspired by the classic "Cash Book" feature set, then
polished and fixed where the original was weak.

**No ads. No trackers. Your data never leaves your device** unless you
export it yourself.

## Features

- **Multiple cash books** (accounts) with per-book balances and a total
  balance dashboard
- **Cash in / cash out entries** with automatic running balance, grouped
  by day, with search and in/out filters
- **Transfers between books** (paired entries that always stay in sync,
  including in the recycle bin)
- **Categories** for income and expenses (customisable), plus notes,
  descriptions and up to **3 receipt photos** per entry
- **Reports**: week / month / year summaries, in-vs-out bar chart,
  per-category breakdown, month calendar with daily net indicators,
  **PDF export** (shareable)
- **Notebook** for dated to-dos and reminders
- **Denomination counter** for counting physical cash against the book
- **Recycle bin**: soft-deleted entries can be restored or purged
- **App lock** using the device credential / biometrics (no custom PIN
  stored in the app)
- **Encrypted backup & restore**: AES-256 backup files protected by a
  passphrase you choose — the fix for the reference app's plain `.db`
  backups. Plain JSON export is also available.
- **Bilingual UI**: Bahasa Indonesia (default) and English
- Material 3 design, dark mode, Plus Jakarta Sans typography

## Data model

Local SQLite (`sqflite`), deliberately following the proven shape of
the analysed reference app:

| Table              | Purpose                                   |
| ------------------ | ----------------------------------------- |
| `accounts`         | cash books (soft-deletable)               |
| `cash_transactions`| entries: `cash_in`/`cash_out`, notes, description, bill photos, soft-delete flags, transfer pairing |
| `categories`       | income/expense categories                 |
| `notebook`         | dated notes with completion flag         |
| `currency_notes`   | denominations for the cash counter        |
| `settings`         | language, currency, theme, lock           |

## Build

CI does everything (this repo's GitHub Actions):

- **Every push**: `flutter analyze`, `flutter test`, debug APK artifact.
- **Release**: add repo secrets `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`,
  `KEY_ALIAS`, `KEY_PASSWORD` and the same workflow also produces a
  signed release APK + AAB.
- **Google Play**: see `.github/workflows/release-play.yml` — set the
  `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` secret and the
  `PLAY_PUBLISH_ENABLED=true` variable, then run it (or push a `v*` tag)
  to upload the AAB to a Play track automatically.

Locally:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release   # signing via android/key.properties
```

For local release signing, create `android/key.properties` (git-ignored):

```properties
storePassword=...
keyPassword=...
keyAlias=...
storeFile=/absolute/path/to/upload-keystore.jks
```

## Privacy

The app requests only the permissions it needs (biometrics for the app
lock, camera/photos for receipt attachments). It contains no analytics,
no ad SDKs and makes no network calls.
