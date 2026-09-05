# Little Learners

Little Learners is a Flutter e-learning app for toddlers ages 2 to 4. This repository is being built from scratch, using the evaluated Edutainment project only as product inspiration.

## Current Build Slice

- Flutter source skeleton with MVVM-style folders.
- Parent auth flow with demo in-memory repository.
- Parent manual and readiness quiz gate.
- Child profile create/edit/delete with max-3 rule.
- Parental lock math challenge for profile management.
- SQLite-ready child profile cache with `isSynced` tracking.
- Sync service foundation for profile upserts and delete outbox items.
- Content cache foundation for bundled learning modules and Math levels.
- Navigation runs child profile ▸ modules ▸ levels ▸ sequential content. Each level covers one **portion** of its module (English `A – F`, then `G – L`), the levels screen names that portion, a level unlocks only once the previous one is finished, and inside a level the child meets A before B before C.
- Interactive Math counting/matching activity flow.
- Cached level download state for unlocked later levels.
- Child selection screen as the landing screen after sign-in: learner faces and names only, with the parent dashboard behind a parental-lock button.
- Six ready-made avatars plus camera/gallery profile photos, each asked for with an in-app consent step before the system permission prompt.
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
- Learning content card audio playback for English, Urdu, logic, storytelling, and drawing `audioCueKey` prompts.
- Adapted parent leaderboard, admin dashboard, and keypad-style parental lock screens from the supplied Flutter screen packs while keeping app data wired to repositories/viewmodels.
- Firebase-ready parent auth and onboarding persistence adapters.
- Firebase-ready child profile sync with offline cache, push, pull, and remote delete cleanup.
- Firebase-ready learning progress sync for completed levels, quiz scores, rewards, and watched video lessons.
- Firebase-ready content/admin sync for modules, levels, activity cards, quiz questions, and video lessons.
- Firebase-ready admin content CRUD for draft/published modules and levels.
- Admin role enforcement for content CRUD, including a repository guard and route-level access state.
- Media asset backend pipeline with upload/list/delete repositories, Firestore metadata, and local demo storage.
- Privacy-aware leaderboard backend for opt-in, anonymized, age-stage grouped child rankings.
- Notification delivery backend that turns due reminder preferences into delivery/read records.
- Device-scheduled learning reminders through `flutter_local_notifications`, so a reminder fires with the app closed and returns after a reboot.
- In-app notification centre with unread badge, mark-as-read, swipe-to-delete, and a catch-up pass for reminders that fired while the app was shut.
- Google sign-in alongside email/password, sharing one parent document and onboarding path.
- Password reset through Firebase's own reset email, with the link and the new-password page handled by Firebase.
- Sync orchestration with connectivity-aware task skipping and retry/backoff state.
- Admin publishing workflow with draft, review, published status, versioning, and publish timestamps.
- Parent reporting dashboard for child progress, quiz scores, rewards, watched videos, and profile activity.
- Firebase-ready learning reminder preferences with due-reminder tracking for future notification delivery.

## Local Development

The app runs in Firebase mode by default. Parent auth, onboarding, child profiles, progress, content, reminders, leaderboards, notifications, and media metadata use Firebase-backed implementations. Child profiles, content, and progress also retain their local SQLite caches for offline use.

```sh
flutter pub get
flutter run
```

## Admin Portal

The admin portal runs inside the same app but on a **separate session** from the
parent/child flow (UC-18). Reach it from the **Admin login** link at the bottom of
the parent login screen, or by navigating to `/admin/login`.

Signing in as an admin never authenticates a parent, and signing in as a parent
never grants admin access. In Firebase mode the portal authenticates against a
secondary `FirebaseApp` so it cannot clobber `FirebaseAuth.instance.currentUser`.

Menu (requirement 2):

- **Manage Content** — create/edit/delete modules, levels and quizzes, plus the
  media library.
- **View Parent Accounts** — monitoring-only list of registered parents and their
  child-profile counts.
- **View Progress Statistics** — registered parents, child profiles, module usage
  and level completion.
- **Admin Logout** — confirmation prompt, session termination, redirect to login.

Business rules enforced:

- A module cannot be **published** until it has at least one level.
- Quiz questions are stored on their level, so a quiz always belongs to a level.
- Uploaded media must be assigned to a module.

### Demo mode credentials

With `--dart-define=USE_FIREBASE=false` the portal uses an in-memory admin so it
can be explored without a Firebase project:

```
admin@littlelearners.local / Admin@123
```

These are seeded in `InMemoryAdminAuthRepository` and exist only in demo mode.

### Firebase mode

Admin access is granted by setting `parents/{uid}.role` to `admin` from a trusted
console. The statistics and account screens read across `parents`,
`childProfiles` and `levelProgress`, which requires the admin read grants and the
collection-group rules in `firestore.rules` — deploy those before using the
portal against Firebase, or every query returns permission-denied.

## Backend Setup

The Android app is registered with Firebase through `android/app/google-services.json`. Firestore disk persistence is enabled during startup and Firebase Storage holds uploaded media bytes.

Launch normally to use Firebase:

```sh
flutter run
```

For isolated local development, Firebase can still be disabled explicitly:

```sh
flutter run --dart-define=USE_FIREBASE=false
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
- Media asset metadata in `mediaAssets/{assetId}` documents and uploaded bytes in Firebase Storage under `mediaAssets/{type}/{assetId}/{fileName}`.
- Age-stage leaderboard entries in `leaderboards/stage-{stage}/entries/{childId}` documents.
- Notification deliveries in `parents/{uid}/notificationDeliveries/{deliveryId}` documents.

Local demo mode treats `admin@littlelearners.local` as an admin email after signup. For Firebase mode, promote an approved account by setting `parents/{uid}.role` to `admin` from a trusted backend/admin console. A draft Firestore rules file is included at `firestore.rules` to enforce the same content-admin boundary server-side.

Security rules are included in `firestore.rules` and `storage.rules`. Deploy them with `firebase deploy --only firestore:rules,firestore:indexes,storage` after authenticating the Firebase CLI. Password reset email templates are configured in the Firebase console — see `MANUAL_SETUP.md` item 0b, and item 0a for the Google sign-in fingerprints. The supplied Android JSON does not configure iOS; add `GoogleService-Info.plist` or run `flutterfire configure` before building for Apple platforms.

## Audio Cues

Audio cues are powered by `audioplayers` and can come from either bundled app assets or backend-hosted files:

- Koala Guide files go in `assets/audio/koala/`.
- Learning card files go in `assets/audio/learning/`.
- A Koala cue key like `koala_math_intro` resolves to `assets/audio/koala/koala_math_intro.mp3`.
- A learning cue key like `english_letter_a` resolves to `assets/audio/learning/english_letter_a.mp3`.
- A cue key that is already a full `https://...` URL plays from that remote source, which is the path to use for Firebase Storage/CDN-backed admin content.
- If the file or URL cannot be played, the app falls back to the safe platform sound cue so the audio button never breaks the flow.
