# ЧитајЛесно (dyslexia_app)

Flutter app that helps children with dyslexia read Macedonian texts:
listening (Azure TTS), scanning (Tesseract OCR), text simplification,
reading aids and per-account saved texts synced with Firebase.

## Local setup

1. Install Flutter (Dart SDK ^3.9) and run `flutter pub get`.
2. Copy `.env.example` to `.env` and fill in your own values. `.env` is
   git-ignored and must never be committed.

   **Everything in `.env` is packaged into the APK** (it is a Flutter asset),
   so the Azure key in it can be extracted from any APK built with it. Do not
   share or publish such APKs; use a key you can rotate.
3. Firebase client configuration (`android/app/google-services.json`,
   `lib/firebase_options.dart`) identifies the Firebase project and is not a
   secret. Access is enforced by `firestore.rules`. Never add service-account
   keys, keystores or `key.properties` to the repository.
4. Optional text simplification backend: see [`backend/README.md`](backend/README.md).
   Its secrets go in `backend/.env` (git-ignored), based on `backend/.env.example`.

## Checks

```powershell
flutter analyze
flutter test
```

Firestore rules tests (emulator, Java required):

```powershell
npm --prefix firestore_tests install
npx firebase-tools@14.27.0 emulators:exec --only "auth,firestore" --project demo-chitajlesno "npm --prefix firestore_tests test"
```

## Firestore rules and indexes

`firestore.rules` and `firestore.indexes.json` are deployed separately:

```powershell
npx firebase-tools@14.27.0 deploy --only "firestore:rules,firestore:indexes" --project dyslexia-app-mk-2026
```
