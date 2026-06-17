# MOGas — Play Store Readiness Checklist

**Project:** `mogas` — "MOGas MOMoney", a Missouri Motor Fuel Tax Refund tracker (Flutter, Riverpod, SQLite, Google ML Kit OCR).
**Package / applicationId:** `tech.reqs.mogas`
**Purpose of this file:** An ordered, self-contained punch list to make the app correct, complete, and packageable for the Google Play Store. Each item lists the file(s), the exact change, why it matters, and how to verify. Written so a fresh assistant with no prior context can execute it.

> How to use: work top to bottom. Check the box when done. Items in **PHASE 1–2** are quick and low-risk; **PHASE 3** is the one real security fix; **PHASE 4–6** are build & submission. Don't skip the verification line under each item.

---

## PHASE 1 — Remove dead / leftover code (low risk, do first)

These don't break the build but are dead weight; two are placeholder screens from an unrelated template and look unfinished if ever reached.

- [x] **1.1 Delete the empty widget file.** `lib/widgets/custom_card.dart` is 0 bytes and imported nowhere.
  - Verify: `grep -rn "custom_card\|CustomCard" lib/` returns nothing.

- [x] **1.2 Delete the unused in-memory store.** `lib/services/receipt_store.dart` (`ReceiptStore`) is never referenced; real persistence is the SQLite DB.
  - Verify: `grep -rn "receipt_store\|ReceiptStore" lib/` returns nothing.

- [x] **1.3 Delete the orphaned wellness placeholder screens** (leftovers from a different template, never navigated to):
  - `lib/screens/status_screen.dart` (Sleep/Mood/Energy/Physical tracker)
  - `lib/screens/focus_screen.dart` ("Focus tasks go here")

- [x] **1.4 Delete the orphaned read-only review screen.** `lib/screens/receipt_review_screen.dart` — superseded by the editable in-scanner flow; nothing pushes `/review`.

- [x] **1.5 Remove the now-dead routes + imports in `lib/main.dart`.** Delete these route lines:
    ```dart
    '/status': (context) => const StatusScreen(),
    '/focus': (context) => const FocusScreen(),
    '/review': (context) => const ReceiptReviewScreen(),
    ```
    and their matching `import` lines at the top (`status_screen.dart`, `focus_screen.dart`, `receipt_review_screen.dart`).
  - Verify: `grep -rn "StatusScreen\|FocusScreen\|ReceiptReviewScreen\|'/status'\|'/focus'\|'/review'" lib/` returns nothing.

- [x] **1.6 Delete the stale MainActivity from the old package name.** Remove the whole folder `android/app/src/main/kotlin/com/example/`. The only MainActivity that should remain is `android/app/src/main/kotlin/tech/reqs/mogas/MainActivity.kt`.
  - Verify: `find android -name MainActivity.kt` lists only the `tech/reqs/mogas` one.

- [x] **1.7 Re-run the wiring check.** (verified by grep: all imports resolve, no refs to removed code; run `flutter analyze` on your machine to confirm with the real compiler) Confirm no imports broke:
  - Verify: `flutter analyze` reports no errors (see Phase 5 if Flutter isn't installed yet).

---

## PHASE 2 — Quick manifest hardening

- [x] **2.1 Disable cloud auto-backup of app data.** In `android/app/src/main/AndroidManifest.xml`, on the `<application>` tag add:
    ```xml
    android:allowBackup="false"
    android:fullBackupContent="false"
    ```
    Why: backup currently defaults to `true`, so app data (which today includes plaintext SSN / bank details — see Phase 3) could sync to the user's Google Drive.

- [x] **2.2 Scope the legacy storage permission.** (added `android:maxSdkVersion="32"`) In the same manifest, change the read-external-storage line to:
    ```xml
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
    ```
    Why: superseded by `READ_MEDIA_IMAGES` on Android 13+ (API 33+).

- [ ] **2.3 Confirm INTERNET permission is intentional.** `privacy.html` says all processing is on-device. ML Kit (latin), image_picker, and printing don't require network. DECISION (left to confirm): INTERNET permission was **kept in place** for now (harmless default); make sure Play's Data Safety form reflects that no user data is transmitted off-device. Remove the permission if you want to guarantee no network access.

---

## PHASE 3 — SERIOUS: stop storing PII in plaintext (do before any public release)

**Problem:** `lib/models/profile.dart` → `toPrefsJson()` writes `ssn`, `spouseSsn`, `fein`, `bankRoutingNumber`, `bankAccountNumber` into SharedPreferences as plain JSON (saved by `lib/providers/providers.dart` → `ProfileNotifier.save`). The model's comments claim "encrypted at rest via flutter_secure_storage," but that package is commented out in `pubspec.yaml` and used nowhere. For an app handling SSNs and bank info this is the top risk and affects the Play Data Safety declaration.

- [ ] **3.1 Re-enable the dependency.** In `pubspec.yaml`, uncomment / add:
    ```yaml
    flutter_secure_storage: ^9.2.2
    ```
    Then `flutter pub get`.

- [ ] **3.2 Split the profile model into sensitive vs. non-sensitive persistence.**
  - Keep non-sensitive fields (names, address, city, state, zip, email, phone, fax, filerType, bankAccountType) in SharedPreferences via `toPrefsJson()` / `fromPrefsJson()`.
  - Move the 5 sensitive fields (`ssn`, `spouseSsn`, `fein`, `bankRoutingNumber`, `bankAccountNumber`) to `flutter_secure_storage` (Android Keystore-backed).
  - Update the comments in `profile.dart` to match reality.

- [ ] **3.3 Update `ProfileNotifier` (`lib/providers/providers.dart`)** so `save()` writes non-sensitive fields to prefs and sensitive fields to secure storage, and `_load()` reads from both and merges. Keep the API (`save(Profile)`) unchanged so screens don't need edits.

- [ ] **3.4 One-time migration.** On load, if a legacy `profile` prefs blob still contains the sensitive keys, move them into secure storage and strip them from the prefs JSON, then re-save. Prevents leaving old plaintext behind on existing installs.

- [ ] **3.5 Verify.** Save a profile with test SSN/bank values, then inspect `shared_prefs` XML on a device/emulator (`adb shell run-as tech.reqs.mogas cat /data/data/tech.reqs.mogas/shared_prefs/*.xml`) and confirm those 5 values are **not** present in plaintext.

---

## PHASE 4 — Signing & version

- [ ] **4.1 Confirm the release keystore exists** at the path in `android/key.properties`: `C:/Users/reqs/keys/mogas-release.jks`. (Good: `key.properties` and `*.jks` are already gitignored — keep it that way; never commit them.)
- [ ] **4.2 Back up the keystore + passwords somewhere safe.** If lost, you can't update the app on Play.
- [ ] **4.3 Set the release version.** In `pubspec.yaml`, `version: 1.0.0+1` → versionName `1.0.0`, versionCode `1`. Increment the `+N` (versionCode) for every subsequent Play upload.

---

## PHASE 5 — Build & test (must pass on a machine with the Flutter SDK)

- [ ] **5.1** `flutter pub get`
- [ ] **5.2** `flutter analyze` — zero errors.
- [ ] **5.3** `flutter test` — if/when tests exist (there is no `test/` dir yet; optional but recommended for the receipt parser).
- [ ] **5.4** Confirm `targetSdk` resolves to **35 or higher** (Play requires API 35 for new apps as of Aug 2025). It's set to `flutter.targetSdkVersion` in `android/app/build.gradle.kts`; check the resolved value in the build output, or pin it explicitly to `35`.
- [ ] **5.5 Build the release App Bundle:** `flutter build appbundle --release` → produces `build/app/outputs/bundle/release/app-release.aab`.
- [ ] **5.6 Smoke-test the release build** on a physical Android device: scan a receipt, save it, generate the 4923-H PDF, edit/delete a receipt, set up a profile.

---

## PHASE 6 — Play Console submission prerequisites

- [ ] **6.1** Host the privacy policy (`privacy.html`) at a public URL and put that URL in the Play listing. (Required — the app collects SSN/bank data.)
- [ ] **6.2** Complete the **Data Safety** form: declare collection of financial info (bank), government ID (SSN/FEIN), and that data is stored on-device/encrypted (after Phase 3). Reconcile with the INTERNET decision from 2.3.
- [ ] **6.3** Store listing assets: app icon (512×512), feature graphic (1024×500), ≥2 phone screenshots, short + full description.
- [ ] **6.4** Content rating questionnaire, target audience, and ads declaration (app has no ads).
- [ ] **6.5** Upload the `.aab`, roll out to internal testing first, then production.

---

## Reference — current audit verdict (as of this checklist)

- Structurally sound: correct package id, namespace, signing wiring, DB schema matches models, all imports resolve, core scan→OCR→edit→save flow complete.
- OCR parser (`lib/services/receipt_parser.dart`) recently gained a trailing-unit gallons pattern (handles `18.638G`). Still-open parser gap (optional, not a blocker): totals labeled `FUEL SALE` (no "total" keyword) aren't captured.
- Fuel type on saved receipts comes from the selected vehicle, not OCR — so OCR fuel-type misses don't affect saved data.
