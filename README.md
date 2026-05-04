# 🏋️ Beast Mode — Social Fitness Tracker
**Flutter + Firebase | Mobile App Development Final Project**
Developer: Jason Lopez | ID: 002723360

---

## Quick Setup (5 Steps)

### 1. Clone & Install
```bash
git clone https://github.com/Jsiinn/project2-social-fitness-tracker
cd project2-social-fitness-tracker
flutter pub get
```

### 2. Connect Your Firebase Project
Replace `lib/firebase_options.dart` with your actual Firebase config:
```bash
# Install FlutterFire CLI if not installed
dart pub global activate flutterfire_cli

# Auto-generate firebase_options.dart from your project
flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
```

### 3. Deploy Firestore & Storage Rules
```bash
firebase deploy --only firestore:rules
firebase deploy --only storage
```

### 4. Deploy Cloud Functions
```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

### 5. Run the App
```bash
flutter run
```

---

## Project Structure
```
lib/
├── main.dart                    # App entry, Firebase init, routing
├── firebase_options.dart        # ⚠️ Replace with your config
├── services/
│   ├── auth_service.dart        # Firebase Auth + FCM token management
│   ├── firestore_service.dart   # All Firestore CRUD + real-time streams
│   ├── storage_service.dart     # UID-scoped photo uploads
│   └── fcm_service.dart         # Push notification handlers
├── models/
│   ├── workout_model.dart       # Workout, ExerciseSet, AIFlag
│   └── feed_post_model.dart     # FeedPost, ChallengeModel
└── screens/
    ├── auth/                    # Login + Register
    ├── home/                    # Activity Feed (real-time)
    ├── workout/                 # Log Workout + AI overlay
    ├── challenges/              # Challenge system + leaderboard
    ├── dashboard/               # Progress charts (fl_chart)
    ├── photos/                  # Photo Journal (Storage)
    ├── profile/                 # Profile + notification prefs
    └── shell_screen.dart        # Bottom nav bar

functions/
└── index.js                     # Cloud Functions: AI overexertion + FCM alerts

firestore.rules                  # UID-scoped Firestore security rules
storage.rules                    # UID-scoped Storage security rules
test/
└── ai_overexertion_test.dart    # Unit tests for all 3 AI thresholds
```

---

## Firebase Services Used
| Service | Implementation |
|---|---|
| **Firebase Auth** | Email/password login, register, session persistence |
| **Firestore** | Real-time workout logs, feed, challenges, notifications |
| **Firebase Storage** | UID-scoped pre/post workout photos, avatars |
| **FCM** | Challenge alerts, overexertion warnings, milestone notifications |
| **Cloud Functions** | AI overexertion detection, FCM delivery, leaderboard updates |

---

## Firestore Collections
```
/users/{uid}           → profile, stats, FCM token, weekly goals
/workouts/{workoutId}  → exercise log, intensity, aiFlag (set by Cloud Function)
/feed/{postId}         → social posts, likes array
/challenges/{id}       → title, participants, leaderboard, status
/notifications/{id}    → queued by Cloud Functions, read by FCM
```

---

## Running Tests
```bash
# Unit tests for AI overexertion thresholds
flutter test test/ai_overexertion_test.dart

# All tests
flutter test
```

---

## Building APK
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## Key Security Rules
- All Firestore paths are UID-scoped (`request.auth.uid == resource.data.uid`)
- Storage paths follow `/users/{uid}/photos/{filename}` — cross-user reads are denied
- Challenge documents: creator-only write; participants can only modify the `participants` array
- Notifications: Cloud Functions (Admin SDK) write-only; users read their own only

---

## AI Overexertion Module
Cloud Function triggers on every new `/workouts/{workoutId}` document.
Evaluates 3 thresholds:
1. **Intensity spike** — today > 7-day avg by more than 2.5 points
2. **Rest gap** — < 12h for strength, < 4h for cardio  
3. **Goal mismatch** — exceeded weekly session target

Writes `aiFlag` back to workout doc → Flutter client listens via `onSnapshot` → shows overlay modal with explainable reasons.
