# Little Learners

Little Learners is a Flutter e-learning app for toddlers ages 1 to 4. This repository is being built from scratch, using the evaluated Edutainment project only as product inspiration.

## Current Build Slice

- Flutter source skeleton with MVVM-style folders.
- Parent auth flow with demo in-memory repository.
- Parent manual and readiness quiz gate.
- Child profile create/edit/delete with max-3 rule.
- Parental lock math challenge for profile management.
- SQLite-ready child profile cache with `isSynced` tracking.
- Sync service foundation for profile upserts and delete outbox items.
- Content cache foundation for bundled learning modules and Math levels.
- Interactive Math counting/matching activity flow.
- Cached level download state for unlocked later levels.
- Child profile selection.
- Child learning dashboard.
- Module level map and unlock logic.
- Generic activity, quiz, reward flow.
- First-class Video Learning module with a video lesson player route.
- English learning module with staged phonics, simple words, quizzes, downloadable practice, and audio cue keys.
- Urdu learning module with staged Haroof/word content, RTL Nastaliq rendering, and audio cue keys.
- Logic learning module with staged shape, comparison, sorting, pattern, and puzzle practice.
- Storytelling module with staged picture talk, sequencing, story creation, quizzes, and downloadable practice.
- Drawing/coloring module with staged mark-making, shape drawing, color prompts, quizzes, downloadable practice, and color-swatch interaction.
- Koala Guide guidance system with seeded and admin-synced child/parent messages, context-aware selection, real asset/URL audio playback, parent tips, and app-wide prompt integration.
- Firebase-ready parent auth and onboarding persistence adapters.
- Firebase-ready child profile sync with offline cache, push, pull, and remote delete cleanup.
- Firebase-ready learning progress sync for completed levels, quiz scores, rewards, and watched video lessons.
- Firebase-ready content/admin sync for modules, levels, activity cards, quiz questions, and video lessons.
- Firebase-ready admin content CRUD for draft/published modules and levels.
- Admin role enforcement for content CRUD, including a repository guard and route-level access state.
- Media asset backend pipeline with upload/list/delete repositories, Firestore metadata, and local demo storage.
- Privacy-aware leaderboard backend for opt-in, anonymized, age-stage grouped child rankings.
- Notification delivery backend that turns due reminder preferences into delivery/read records.
- Sync orchestration with connectivity-aware task skipping and retry/backoff state.
- Admin publishing workflow with draft, review, published status, versioning, and publish timestamps.
- Parent reporting dashboard for child progress, quiz scores, rewards, watched videos, and profile activity.
- Firebase-ready learning reminder preferences with due-reminder tracking for future notification delivery.

## Local Development

The app runs in local demo mode by default. Parent auth, onboarding, parental lock, profile sync, and content sync all use local or in-memory implementations unless a backend mode is enabled.

```sh
flutter pub get
flutter run
```

## Backend Setup

Parent authentication and parent onboarding progress now have Firebase-backed repository adapters. They are disabled by default so the app remains runnable before API credentials are available.

When Firebase configuration is ready, run the FlutterFire setup for this project, add the generated platform config files, then launch with:

```sh
flutter run --dart-define=USE_FIREBASE=true
```

Firebase mode currently persists:

- Parent accounts through Firebase Authentication.
- Parent onboarding state and parent role in `parents/{uid}` documents.
- Manual completion, last viewed manual page, readiness score, and readiness pass status.
- Child profiles in `parents/{uid}/childProfiles/{childId}` documents.
- Child profile create/update/delete sync from the local SQLite cache.
- Learning progress in `childProgress/{childId}/levelProgress/{levelId}` documents.
- Completed levels, stars, quiz scores, rewards, and video watch progress from the local SQLite cache.
- Admin content in `learningModules/{moduleId}` and `learningLevels/{levelId}` documents.
- Published content replaces the local content cache while preserving downloaded level state.
- Admin CRUD writes draft/published module and level documents into those same collections.
- Koala Guide messages in `koalaGuideMessages/{messageId}` documents.
- Published Koala Guide messages sync into the app and override bundled seed guide messages.
- Admin CRUD requires `parents/{uid}.role` to be `admin`; new Firebase parent documents default to `parent`.
- Admin content stores `publishStatus`, `version`, `submittedAt`, and `publishedAt` workflow metadata.
- Learning reminders in `parents/{uid}/learningReminders/{reminderId}` documents.
- Media asset metadata in `mediaAssets/{assetId}` documents; local demo mode stores uploaded bytes in memory through the same repository contract.
- Age-stage leaderboard entries in `leaderboards/stage-{stage}/entries/{childId}` documents.
- Notification deliveries in `parents/{uid}/notificationDeliveries/{deliveryId}` documents.

Local demo mode treats `admin@littlelearners.local` as an admin email after signup. For Firebase mode, promote an approved account by setting `parents/{uid}.role` to `admin` from a trusted backend/admin console. A draft Firestore rules file is included at `firestore.rules` to enforce the same content-admin boundary server-side.

Draft security rules are included in `firestore.rules` and `storage.rules`. The media repository already uses a storage adapter interface; local/demo builds use in-memory storage so the app remains dependency-light until the Firebase Storage package can be fetched and configured.

## Koala Guide Audio

Koala audio cues are powered by `audioplayers` and can come from either bundled app assets or backend-hosted files:

- Bundled files go in `assets/audio/koala/`.
- A cue key like `koala_math_intro` resolves to `assets/audio/koala/koala_math_intro.mp3`.
- A cue key that is already a full `https://...` URL plays from that remote source, which is the path to use for Firebase Storage/CDN-backed admin content.
- If the file or URL cannot be played, the app falls back to the safe platform sound cue so the Koala button never breaks the flow.
