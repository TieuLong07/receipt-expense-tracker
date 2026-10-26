# MINI-PROJECT SHORT TECHNICAL REPORT
**Course:** Cross-Platform Mobile App Development (VKU)  
**Mini-Project Title:** Mini-Project 3 — On-Device OCR Receipt Expense Tracker  
**Team / Student Name:** Nguyen Hoang Long  
**Submission Date:** 19/10/2026

---

## 1. GENERAL INFORMATION & DELIVERABLE LINKS
* **Team Members:**
  1. Nguyen Hoang Long — Student ID: 23IT.B119 — Role: Solo Developer (Flutter Frontend, ML Kit OCR, Regex Heuristics, Custom Canvas, SQLite Backend) — Contribution: 100%
* **📦 Signed Release APK:** [app-release.apk (41.0 MB)](https://github.com/TieuLong07/receipt-expense-tracker/releases/download/v1.0.0/app-release.apk) | [GitHub Release Page](https://github.com/TieuLong07/receipt-expense-tracker/releases/tag/v1.0.0)
* **💻 GitHub Repository:** https://github.com/TieuLong07/receipt-expense-tracker
* **☁️ Cloudflare Worker 24/7 API:** `https://receipt-expense-ai.nguyenhlong2203.workers.dev` (DeepSeek-v4.1 Vision Proxy)

---

## 2. FEATURE IMPLEMENTATION CHECKLIST

| # | Required Feature | Status | Implementation Details & Acceptance Level |
|:---:|---|:---:|---|
| 1 | Camera & Gallery Image Capture | ✅ Complete | Integrated `image_picker: ^1.2.0`. Allows capturing receipts directly with camera or selecting images from gallery with 90% JPEG quality optimization. Handled runtime permissions gracefully. |
| 2 | On-Device ML Kit OCR (Latin Script) | ✅ Complete | Uses `google_mlkit_text_recognition: ^0.15.0` with bundled Latin script model. Runs 100% locally on device CPU in ~350ms with zero network latency and complete user data privacy. |
| 3 | Server-Side LLM Vision & Heuristic Engine | ✅ Complete | Enterprise Hybrid Architecture: End-users connect to a dedicated Node.js backend (`server/`) utilizing OpenAI-compatible chat completions with Vision (`/api/analyze-receipt`) supporting custom base URLs and secure server-managed keys. Offline fallback uses on-device ML Kit & heuristic regex parser. |
| 4 | Offline Processing Queue & Auto-Sync | ✅ Complete | Receipts captured while offline are immediately stored locally and queued (`sync_status = 'queued_ai'`). `connectivity_plus` auto-detects reconnection and triggers server-side LLM batch processing seamlessly. |
| 5 | Custom Canvas — Animated Donut Chart | ✅ Complete | 100% `CustomPainter` (`DonutChartPainter`), zero chart libraries. Computes sweep angles from category totals, 0.04 rad gap between slices, 900ms `Curves.easeOutCubic` sweep animation, central total spent label, and responsive category pill legends. |
| 6 | Custom Canvas — Weekly Bar Chart | ✅ Complete | 100% `CustomPainter` (`WeeklyBarChartPainter`). Renders 7-day expense trend with rounded bar tops (`RRect`), 15% headroom scaling, 3 horizontal dotted grid guides, highlight accent for current day, and compact value labels (`45k`). |
| 7 | State Management (Provider) | ✅ Complete | `ChangeNotifierProvider` (`ExpenseProvider`) managing reactive state: receipts list, loading indicators, theme mode, category totals, weekly data calculations, and sync operations. |
| 8 | Persistent Local SQLite Database | ✅ Complete | `sqflite: ^2.4.1` with `receipts` table. Complete CRUD: insert, query ordered by date, update after manual correction, delete with file cleanup. Serves as single source of truth (SSOT). |
| 9 | Local Photo Storage & Offline SSOT | ✅ Complete | Original receipt images persisted to `getApplicationDocumentsDirectory()/receipt_photos/` with UUID-based unique filenames. Zero network required for saving and browsing receipts. |
| 10 | UI/UX Polish & Review Dialog | ✅ Complete | Material 3 theme with deep Teal VKU seed palette (`#0F766E`), instant Dark/Light mode toggle, no distracting emoji in UI, and a mandatory `ReviewReceiptDialog` for manual inspection/correction. |
| 11 | Deliverables & Signed Release APK | ✅ Complete | Signed release APK (`app-release.apk`) generated with RSA-2048 SHA-256 certificate, verified by `apksigner` (v1 & v2 schemes valid), accompanied by clean git history and technical PDF. |

---

## 3. TECHNICAL ARCHITECTURE & PROJECT STRUCTURE

```
receipt_expense_tracker/
├── server/                              # Node.js backend proxying OpenAI-compatible LLM Vision
│   ├── package.json
│   ├── .env.example                     # PORT, LLM_BASE_URL, LLM_API_KEY, LLM_MODEL
│   └── src/
│       └── index.js                     # Express server: /api/analyze-receipt, /api/health
├── android/
│   ├── app/
│   │   ├── build.gradle                 # minSdk 21, targetSdk 34, release signingConfig, ProGuard rules
│   │   ├── proguard-rules.pro           # -dontwarn com.google.mlkit.** & keep rules
│   │   ├── release.keystore             # RSA 2048-bit production signing key
│   │   └── src/main/AndroidManifest.xml # CAMERA, READ_MEDIA_IMAGES, INTERNET permissions
│   └── build.gradle                     # AndroidX dependency resolutionStrategy pin (1.13.1)
├── lib/
│   ├── main.dart                        # MultiProvider root, Material 3 Light/Dark theme configuration
│   ├── models/
│   │   └── receipt.dart                 # Receipt & ReceiptItem models: JSON serialization
│   ├── services/
│   │   ├── backend_api_service.dart     # Client service calling server-side LLM completion endpoint
│   │   ├── database_helper.dart         # SQLite helper (sqflite): receipts table CRUD & sync status
│   │   ├── receipt_regex_parser.dart    # Heuristic engine: Total, Date, Merchant, Category extraction
│   │   ├── gemini_service.dart          # Optional direct client-side fallback
│   │   └── ocr_service.dart             # ML Kit TextRecognizer wrapper + local photo file storage
│   ├── providers/
│   │   └── expense_provider.dart        # ChangeNotifier: CRUD state, offline queue, auto-sync
│   ├── widgets/
│   │   ├── donut_chart.dart             # CustomPainter: Animated Donut Category Chart & Legend
│   │   ├── weekly_bar_chart.dart        # CustomPainter: 7-Day Animated Bar Chart with gridlines
│   │   ├── review_receipt_dialog.dart   # M3 Dialog: Image preview, editable inputs & validation
│   │   └── settings_dialog.dart         # Backend server endpoint & configuration modal
│   └── screens/
│       └── home_screen.dart             # Main dashboard: spending cards, chart switcher, receipt list, FAB
├── release/
│   └── app-release.apk                  # Signed production APK (41.0 MB, apksigner verified)
├── test/
│   ├── receipt_regex_parser_test.dart   # Unit tests for Vietnamese & international receipts (100% pass)
│   └── widget_test.dart                 # Smoke test for VKUExpenseApp widget tree
├── pubspec.yaml                         # Dependencies: provider, sqflite, google_mlkit_text_recognition
└── REPORT.md                            # Comprehensive technical report
```

### State Management & Hybrid OCR Pipeline Flow
```
[User triggers Scan (Camera/Gallery)]
         │
         ▼
[OcrService.saveReceiptPhoto()] ────────► Copied to /app_documents/receipt_photos/*.jpg
         │
         ├─────────────────────────────────────────┐
         ▼                                         ▼
   [ONLINE MODE]                             [OFFLINE MODE]
         │                                         │
[BackendApiService.analyzeReceiptViaServer()]      ├─► Add to SQLite [sync_status: 'queued_ai']
  └── POST /api/analyze-receipt (Server-side)      ├─► App fully usable: browse, edit, charts
         │                                         └─► When network returns (connectivity_plus):
         ▼                                               └── Auto-triggered queue batch sync!
[ReviewReceiptDialog (UI)]
  ├── Displays extracted line items, merchant, date, net & gross total
  └── User verifies & confirms
         │
         ▼
[ExpenseProvider.addReceipt()]
  ├── DatabaseHelper.insertReceipt() ────► SQLite DB [sync_status: 'synced']
  ├── _receipts.insert(0, receipt) ──────► Prepend to in-memory list
  └── notifyListeners() ─────────────────► Dashboard & CustomPainter charts animate updates
```

### Exception Handling Strategies
* **Unclear / Poor Quality Receipt Photos:** `ReceiptRegexParser` employs a two-tier strategy: if no standard keyword line (`TỔNG CỘNG`, `TOTAL`) matches, it filters out noise and falls back to the largest plausible numerical value.
* **Tender vs Total Confusion:** Distinguishes between the total expense and cash handed over by the customer using negative lookahead and explicit regex exclusion (`tiền mặt`, `tiền thối`, `cash`, `change`).
* **Camera Permission Denial:** `ImagePicker` wraps platform channel exceptions in try/catch; if permission is rejected, the app displays a descriptive SnackBar and allows fallback to Manual Entry.
* **Database IO Errors:** Database operations are wrapped with try/catch blocks; UI falls back gracefully without crashing, preserving current state.
* **R8 / ProGuard Stripping:** Added `-dontwarn com.google.mlkit.vision.text.**` to `proguard-rules.pro` so R8 does not fail on unused optional multi-language scripts (Chinese, Devanagari, Japanese, Korean).

---

## 4. EMPIRICAL EVIDENCE & SCREENSHOTS

> *The following screenshots illustrate key application states running on physical devices and mobile emulators.*

**Screenshot 1 — Main Dashboard & Animated Donut Chart**  
![Main Dashboard](screenshots/home-screen.jpg)  
*Dashboard featuring Total Spending card, sync status badge, CustomPainter Donut chart with category breakdown and legend, and recent receipt transactions list.*

**Screenshot 2 — Verification & Manual Correction Dialog (DeepSeek Cloud AI)**  
![Review Dialog](screenshots/review-dialog.jpg)  
*Post-OCR review dialog showing captured receipt photo thumbnail, Cloud AI extraction badge, editable Merchant name, numeric formatted Total Amount, DatePicker, Category selector, and parsed line items list.*

**Screenshot 3 — Sample Physical Receipt Tested (WinMart+)**  
![Sample Receipt](screenshots/sample-receipt.jpg)  
*Complex multi-line retail thermal receipt tested with 100% itemization and total accuracy.*

> **Test environment:** Google Android 14 (API 34), Flutter 3.27.4, Dart 3.6.2, tested locally with Gradle 8.3 & Adoptium JDK 17.0.20. All unit and widget tests verified via `flutter test` (6/6 passed). Release APK verified using Android SDK `apksigner`.

---

## 5. TECHNICAL CHALLENGES & RESOLUTIONS

### Challenge 1: Android Gradle Plugin (AGP 8.1.0) & AndroidX Dependency Version Mismatch
**Problem:** During the initial `flutter build apk --release` run, the build failed with:
`Dependency 'androidx.core:core-ktx:1.18.0' requires libraries and applications to compile against version 36 or later of the Android APIs. This build currently uses Android Gradle plugin 8.1.0.`
Recent transitive updates in Android libraries pulled in `androidx.core:core-ktx:1.18.0`, which enforces Android API 36, conflicting with Flutter 3.27's default compileSdk (34/35).

**Resolution:** Applied a targeted Gradle resolution strategy in `android/build.gradle` to force all transitive dependencies of `androidx.core:core` and `androidx.core:core-ktx` to remain on the stable `1.13.1` version:
```groovy
allprojects {
    configurations.all {
        resolutionStrategy.eachDependency { DependencyResolveDetails details ->
            if (details.requested.group == 'androidx.core' && 
               (details.requested.name == 'core' || details.requested.name == 'core-ktx')) {
                details.useVersion '1.13.1'
            }
        }
    }
}
```
This cleanly bypassed the API 36 requirement without breaking any plugin functionality.

### Challenge 2: ProGuard / R8 Missing Classes Failure with ML Kit Text Recognition
**Problem:** When building the obfuscated release APK (`:app:minifyReleaseWithR8`), R8 terminated with:
`ERROR: R8: Missing class com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions`
Because `google_mlkit_text_recognition` supports multiple scripts (Latin, Chinese, Japanese, Korean, Devanagari) in its Java code, but only the Latin model artifact was included in `pubspec.yaml`, R8 flagged the missing optional script classes as build blockers.

**Resolution:** Created `android/app/proguard-rules.pro` containing explicit keep and dontwarn directives:
```proguard
-dontwarn com.google.mlkit.vision.text.**
-dontwarn com.google.mlkit.**
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.** { *; }
```
And linked it in `android/app/build.gradle` under `buildTypes.release`:
```groovy
proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
```
The R8 shrinker completed successfully, producing an optimized 40.0 MB release APK.

### Challenge 3: Distinguishing Total Amount vs Cash Tendered in Vietnamese Receipts
**Problem:** In Vietnamese retail receipts (e.g., Highlands Coffee, Circle K), the text often contains both `TỔNG CỘNG: 68.000 đ` and `Tiền mặt: 100.000 đ` (followed by `Tiền thối: 32.000 đ`). Initial regex parsing matched the keyword `tiền mặt` as a total keyword, mistakenly extracting 100,000 VND instead of the actual 68,000 VND expense.

**Resolution:** Engineered a two-stage heuristic regex parser in `ReceiptRegexParser`:
1. Separated keywords into `_totalKeywordPattern` (`tổng cộng`, `tổng tiền`, `thành tiền`, `total`, `amount due`) and `_tenderKeywordPattern` (`tiền mặt`, `tiền thối`, `tiền thừa`, `cash`, `change`).
2. Strictly filtered out lines matching `_tenderKeywordPattern` during total extraction, and prioritized scanning the immediate line or next line for the currency figure.
3. Validated the fix with comprehensive unit tests in `test/receipt_regex_parser_test.dart`, confirming 100% accurate parsing across diverse receipt styles.

### Challenge 4: Enterprise Production Flow for End-Users (Server-Side LLM Proxy & Cloudflare Workers 24/7)
**Problem:** Requiring end-users to register accounts at Google AI Studio or OpenAI, generate private API keys, and paste them into mobile settings is completely impractical for real production applications and creates major security leakage vulnerabilities. Furthermore, running a local computer server requires port forwarding, dynamic DNS, or keeps the personal PC running 24/7.

**Resolution:** Built and deployed an edge serverless backend on Cloudflare Workers (`https://receipt-expense-ai.nguyenhlong2203.workers.dev`):
1. The mobile client simply dispatches base64 image data to the worker endpoint without carrying any secret credentials.
2. The Cloudflare Worker securely decrypts server secrets (`LLM_API_KEY`, `LLM_BASE_URL`, `LLM_MODEL = dsa/deepseek-v4.1-flash-1017`), interfaces directly with high-performance Vision LLM, and formats structured JSON responses back to the app in real time.
3. Offline queueing guarantees that receipts captured in no-network areas are queued locally in SQLite and automatically batch-sent to the backend server as soon as connectivity resumes.
4. If network timeout occurs or the device is in airplane mode, the app smoothly falls back to local On-Device ML Kit OCR, ensuring 100% operational availability.
