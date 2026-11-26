# ExamPrep - Production Setup & Deployment Guide

ExamPrep is a cross-platform mobile practice app (Android + iOS) built in Flutter for UPSC Civil Services and TNPSC aspirants.

## Features Summary
1. **Real-time Firebase Authentication**: Email/Password with real email resets, Google Sign-In, and persistent role-based routing (`student` and `admin`).
2. **Admin Question Bank & Batch Ingestion**:
   - Pick `.xlsx` or `.csv` files.
   - Comprehensive validation (schema, option verification, duplicate question detection).
   - Color-coded preview table (green for valid, red with specific errors).
   - Firestore batch write with unique `uploadBatchId` and single-click rollback.
   - Manual Question Editor for single additions, edits, and translations.
   - Admin KPI Dashboard with live count metrics, revenue, and CSV export.
3. **Timed Test Engine**:
   - Anti-cheat server-side timestamp tracking (`startedAt`).
   - Speed Practice options: 100%, 75%, and 50% timer modes.
   - Question palette with Answered, Unanswered, and Marked-for-Review indicators.
   - Real-time Firestore & Local SharedPreferences persistence (resumes across app kills).
   - In-test instant multi-language switching (English, Tamil, Hindi).
   - Automated auto-submission upon timer expiry.
4. **Razorpay Payments (₹1 per Test)**:
   - Order creation generated strictly server-side (`createRazorpayOrder`).
   - Client checkout powered by `razorpay_flutter`.
   - Server-side HMAC SHA-256 signature verification (`verifyPayment`).
   - Test unlock entitlement stored in `user_unlocked_tests/{userId_testId}`.
5. **Real-Time Leaderboard**:
   - Daily, Weekly, and All-Time tabs filtered by UPSC and TNPSC.
   - First-attempt ranking by score descending and time taken ascending.
   - Highlights current user with points, streaks, and badges.
6. **Mains Writing Practice**:
   - Word limit counter with timer and submission archiving.

---

## 1. Firebase Setup

1. Place your configuration files:
   - **Android**: `android/app/google-services.json`
   - **iOS**: `ios/Runner/GoogleService-Info.plist`
2. Update [firebase_options.dart](file:///c:/Users/manoj/OneDrive/Documents/pgi/upsc/examprep/lib/firebase_options.dart) with your project credentials from Firebase Console.
3. Deploy Firestore Security Rules:
   ```bash
   firebase deploy --only firestore:rules
   ```

---

## 2. Setting Up an Admin User

Run the Cloud Function `setAdminRole` or update the user record directly in the Firebase Console:
1. Open Firebase Console -> **Cloud Firestore** -> `users` collection.
2. Locate the user document and set:
   ```json
   {
     "role": "admin"
   }
   ```
3. The Admin Panel icon will automatically appear in the top AppBar for this user.

---

## 3. Deploying Cloud Functions

1. Navigate to the `functions` directory:
   ```bash
   cd functions
   npm install
   ```
2. Configure environment secrets:
   ```bash
   firebase functions:config:set razorpay.key_id="rzp_live_XXXX" razorpay.key_secret="YYYY" gemini.api_key="AIzaSyXXXX"
   ```
3. Deploy functions:
   ```bash
   npm run build
   firebase deploy --only functions
   ```

---

## 4. Build Commands for Production Release

### Android Release
```bash
# Build Split APKs
flutter build apk --release

# Build Android App Bundle (AAB) for Google Play Store
flutter build appbundle --release
```
*Output: `build/app/outputs/bundle/release/app-release.aab`*

### iOS Release
```bash
# Build iOS Archive (on macOS)
flutter build ipa --release
```
*Output: `build/ios/archive/Runner.xcarchive`*

---

## 5. Unified Dashboard Stats Endpoint (Supabase Edge Function)

A read-only stats endpoint `dashboard-stats` is provided for the Unified Dashboard to monitor KPIs from the UPSC / TNPSC platform ("Test 11 - Admin Portal").

### Response Schema
```json
{
  "project": "upsc",
  "stats": {
    "total_students": 18,
    "tnpsc_students": 5,
    "upsc_students": 13,
    "successful_payments": 53,
    "cancelled_payments": 15,
    "failed_payments": 0,
    "inquiries": 1,
    "question_bank": 864,
    "test_packages": 9
  },
  "card_metrics": [
    { "label": "Registered Students", "value": "18", "sub": "TNPSC 5 · UPSC 13" },
    { "label": "Platform Revenue", "value": "₹53", "sub": "53 paid · 15 cancelled · 0 failed" },
    { "label": "Question Bank", "value": "864", "sub": "English, Tamil & Hindi" },
    { "label": "User Inquiries", "value": "1", "sub": "Submitted contact forms" }
  ],
  "revenue_inr": 53,
  "admin_url": "https://unfilteredpodcast011-del.github.io/upsc-app/",
  "generated_at": "2026-11-25T07:15:00.000Z"
}
```

### Key Generation
Generate a cryptographically secure 256-bit hexadecimal key:
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

### Configuration & Deployment
Set the required secrets and deploy with JWT verification disabled (as authentication is handled via the constant-time `x-dashboard-key` header):
```bash
supabase secrets set DASHBOARD_KEY=<generated> ADMIN_PUBLIC_URL=https://unfilteredpodcast011-del.github.io/upsc-app/
supabase functions deploy dashboard-stats --no-verify-jwt
```
*(If running from root with npx: `npx supabase functions deploy dashboard-stats --no-verify-jwt`)*

### Function URL Format
```
https://<project-ref>.supabase.co/functions/v1/dashboard-stats
```
*For this project: `https://jkbndifpcepnsjgmyrfr.supabase.co/functions/v1/dashboard-stats`*

### Curl Examples

#### 1. Missing `x-dashboard-key` header (401 Unauthorized, Empty Body)
```bash
curl -i -X GET https://jkbndifpcepnsjgmyrfr.supabase.co/functions/v1/dashboard-stats
```
**Response:**
```http
HTTP/1.1 401 Unauthorized
Content-Length: 0
```

#### 2. Invalid `x-dashboard-key` header (401 Unauthorized, Empty Body)
```bash
curl -i -X GET https://jkbndifpcepnsjgmyrfr.supabase.co/functions/v1/dashboard-stats \
  -H "x-dashboard-key: invalid_or_wrong_secret_key"
```
**Response:**
```http
HTTP/1.1 401 Unauthorized
Content-Length: 0
```

#### 3. Authorized Request with Valid Key (200 OK)
```bash
curl -i -X GET https://jkbndifpcepnsjgmyrfr.supabase.co/functions/v1/dashboard-stats \
  -H "x-dashboard-key: <YOUR_DASHBOARD_KEY>"
```
**Response:**
```http
HTTP/1.1 200 OK
Content-Type: application/json
Access-Control-Allow-Origin: *

{
  "project": "upsc",
  "stats": {
    "total_students": 18,
    "tnpsc_students": 5,
    "upsc_students": 13,
    "successful_payments": 53,
    "cancelled_payments": 15,
    "failed_payments": 0,
    "inquiries": 1,
    "question_bank": 864,
    "test_packages": 9
  },
  "card_metrics": [
    { "label": "Registered Students", "value": "18", "sub": "TNPSC 5 · UPSC 13" },
    { "label": "Platform Revenue", "value": "₹53", "sub": "53 paid · 15 cancelled · 0 failed" },
    { "label": "Question Bank", "value": "864", "sub": "English, Tamil & Hindi" },
    { "label": "User Inquiries", "value": "1", "sub": "Submitted contact forms" }
  ],
  "revenue_inr": 53,
  "admin_url": "https://unfilteredpodcast011-del.github.io/upsc-app/",
  "generated_at": "2026-11-25T07:15:00.000Z"
}
```

