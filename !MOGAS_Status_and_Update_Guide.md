# MOgas MOmoney — App Status & Update Guide
**Last updated: June 2026**

---

## What the App Is
**MOgas MOmoney** is a Missouri motor fuel tax refund tracker built in Flutter by REQS TECH. It allows users to scan or manually enter fuel receipts, tracks gallons purchased, and calculates the Missouri motor fuel tax refund owed (currently $0.125/gallon). It is live on the Google Play Store.

---

## Current Version
- **Version name:** `1.0.0` (user-facing)
- **Version code:** `4` (internal Google counter)
- **String in pubspec.yaml:** `version: 1.0.0+4`

---

## What's in the App
- OCR receipt scanning via camera
- Manual receipt entry
- Receipt list with sorting (date, gallons, vehicle)
- Refund calculation per receipt and overall summary
- Vehicle management
- Secure storage for sensitive info (SSN, FEIN, bank info)
- PDF generation and printing
- Local SQLite database (data stays on device)

---

## Project Location
- **Path:** `C:\Users\reqs\mogas`
- **IDE:** VS Code
- **Framework:** Flutter (Dart)
- **State management:** Riverpod (FutureProvider)
- **Database:** sqflite (local SQLite)

---

## Key Files to Know
| File | Purpose |
|------|---------|
| `pubspec.yaml` | Dependencies and version number — update version here before every Play Store upload |
| `lib/screens/all_receipts_screen.dart` | The receipt list screen |
| `lib/screens/receipt_form_screen.dart` | Manual receipt entry |
| `lib/screens/receipt_scanner_screen.dart` | OCR camera scanner |
| `lib/screens/edit_receipt_screen.dart` | Edit a saved receipt |
| `lib/providers/providers.dart` | Riverpod providers (state management) |
| `assets/icon/icon.png` | The green 1024x1024 app icon (used in build) |

---

## Play Store Assets
- **Store listing icon:** White background version, 512x512 — uploaded directly to Play Console (not part of the build)
- **App launcher icon:** Green background version, 1024x1024 — lives at `assets/icon/icon.png` and is built into the app

---

## How to Make a Code Change and Update the App

### Step 1 — Open the project
Open VS Code and open the folder `C:\Users\reqs\mogas`

### Step 2 — Make your code changes
Edit whatever files need changing in the `lib/` folder.

### Step 3 — Test on your phone
Plug your phone in via USB with USB debugging enabled, then in the VS Code terminal run:
```
flutter run
```
This installs a debug build directly to your phone so you can test. If it gives a signature mismatch error, just wait — Flutter will uninstall the old version and reinstall automatically.

### Step 4 — Bump the version code
Open `pubspec.yaml` and find this line near the top:
```
version: 1.0.0+4
```
- Change the `+4` to `+5` (or whatever the next number is) — **you must do this every single Play Store upload or Google will reject it**
- Only change `1.0.0` if you've made a meaningful user-facing update (e.g. `1.0.1` for a bug fix, `1.1.0` for new features)

### Step 5 — Build the release bundle
```
flutter build appbundle
```
This creates the file Google needs. It defaults to release mode automatically.

### Step 6 — Find the output file
```
C:\Users\reqs\mogas\build\app\outputs\bundle\release\app-release.aab
```

### Step 7 — Upload to Play Console
1. Go to [play.google.com/console](https://play.google.com/console)
2. Select your app
3. Go to **Production → Create new release**
4. Upload the `app-release.aab` file
5. Roll it out

Users will receive the update automatically or can update manually from the Play Store.

---

## If You Ever Change the App Icon
1. Replace `assets/icon/icon.png` with the new image (must be 1024x1024 PNG)
2. Run: `dart run flutter_launcher_icons`
3. Then rebuild with `flutter build appbundle`

---

## Version Code History
| Version code | What changed |
|---|---|
| +1 | Initial launch |
| +2 | (unknown) |
| +3 | (unknown) |
| +4 | Added green app icon, fixed receipt list not refreshing |

---

## Known Issues Fixed
- **Receipt list not refreshing** — fixed in `+4` by adding `initState` override in `all_receipts_screen.dart` that calls `Future.microtask(() => ref.invalidate(_allReceiptsProvider))` each time the screen is visited
- **No app icon** — fixed in `+4` using `flutter_launcher_icons` package with green 1024x1024 PNG

---

## Things to Remember
- The Play Store listing icon and the in-app launcher icon are **two separate things** — changing one does not change the other
- `flutter run` = debug mode for testing on your phone
- `flutter build appbundle` = release mode for Play Store submission
- Always bump the `+number` in `pubspec.yaml` before every Play Store upload
- Data is stored locally on the user's device — there is no cloud sync or backend server
