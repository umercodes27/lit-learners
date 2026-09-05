# Admin Panel — Implementation & Handover

**Branch:** `feat/admin-panel` (20 commits ahead of `main`)
**Last updated:** 2026-08-26
**Status:** Complete against the written specification, merged with upstream, and
Firebase-ready. **Never executed against a real Firebase project** — see
[Caveats](#caveats-read-before-trusting-this).

> **2026-08-26 — read this first.** The team's work is on
> **`umercodes27/lit-learners`**, not the `nad1r-Rao` fork. `git pull` from
> `origin` reports nothing while upstream moves. An `upstream` remote is
> configured; use `git fetch upstream`.
>
> Upstream was merged on 2026-08-26 (31 commits, 128 files) and the admin panel
> gained a role schema. Sections 1-3 below were updated; §4 is now partly
> out of date and is flagged inline.

Read this before touching the admin panel or the sync layer. It records what
exists, what is deliberately unfinished, and what is already built but never
called — so nothing here gets rebuilt from scratch.

---

## 1. What was implemented

All six admin requirements and use cases UC-18, UC-19, UC-20.

| Spec item | Where |
|---|---|
| UC-18 admin login, separate session | `lib/repositories/admin_auth_repository.dart`, `firebase_admin_auth_repository.dart`, `lib/viewmodels/admin_auth_viewmodel.dart`, `lib/views/admin/admin_login_page.dart` |
| Req 1 — dashboard counts | `lib/views/admin/admin_dashboard_page.dart` |
| Req 2 — four-item menu | same |
| Req 3 / UC-19 — manage content | `lib/views/admin/admin_content_page.dart` (pre-existing, migrated to admin session) |
| UC-19 step 4 — media upload | `lib/views/admin/admin_media_page.dart`, `lib/viewmodels/admin_media_viewmodel.dart` |
| Req 4 — parent accounts | `lib/views/admin/admin_parent_accounts_page.dart` |
| Req 5 — progress statistics | `lib/views/admin/admin_progress_statistics_page.dart` |
| Req 6 / UC-20 — logout | `confirmAdminLogout()` in `lib/views/admin/widgets/admin_scaffold.dart` |
| Statistics data | `lib/models/admin_stats.dart`, `admin_stats_repository.dart`, `firestore_admin_stats_repository.dart`, `local_admin_stats_repository.dart` |
| Admin read rules | `firestore.rules` |
| Admin role schema (2026-08-26) | `lib/models/admin_role.dart`, `lib/models/admin_user.dart`, `lib/services/firebase/admin_user_firestore_service.dart` |
| Firebase connection seam (2026-08-26) | `lib/core/config/firebase_web_options.dart`, `docs/FIREBASE_ADMIN_SETUP.md` |
| Shared admin visual language (2026-08-26) | `lib/views/admin/widgets/admin_theme.dart` |

**Important:** the admin panel was **not** greenfield. A dashboard, an 803-line
content CRUD page with a draft/review/published workflow, `AuthorizedAdminContentRepository`
and admin Firestore rules already existed. This work extended and re-shaped
that. Check what exists before building anything "new".

### Access

Parent login screen → **Admin login** link → `/admin/login`.

Demo mode seeds one admin per role (all password `Admin@123`):

```
admin@littlelearners.local     superAdmin
content@littlelearners.local   contentAdmin
viewer@littlelearners.local    analyticsViewer
```

Firebase mode: create an `adminUsers/{uid}` document. Full steps and the schema
are in **`docs/FIREBASE_ADMIN_SETUP.md`**.

---

## 2. Key design decisions

**The admin session is genuinely separate.** UC-18 requires it. In Firebase mode
`FirebaseAdminAuthRepository` authenticates against a **secondary `FirebaseApp`**.
Using the default app would replace `FirebaseAuth.instance.currentUser` and leak
admin identity into the parent/child flow, making the separation cosmetic. Do
not "simplify" this back to the default app.

**Two authorization repositories now exist.** `AdminSessionAuthorizationRepository`
(admin session) gates admin work. `AuthAdminAuthorizationRepository` (parent
session) is retained for flows keyed off a parent with `role == admin`. Pick
deliberately.

**Firestore rules had to change.** Requirements 4 and 5 were *impossible* before:
parents could only read their own documents, so any system-wide count failed
with permission-denied. Admins now have read access to `parents`,
`childProfiles` and `levelProgress`, plus collection-group rules — those queries
are evaluated against wildcard matches, not the nested paths. Writes are
unchanged and stay parent-only.

**Admin identity lives in its own `adminUsers` collection** (2026-08-26). It used
to be `parents/{uid}.role == 'admin'`, which forced a back-office user to also
be a family and gave no way to say "authors content but must not see parent
emails". Three role ids — `superAdmin`, `contentAdmin`, `analyticsViewer` — are
enforced in the role enum, the authorization decorator and `firestore.rules`.

Two choices worth not undoing: an **unknown role denies access** rather than
defaulting to something permissive, so a console typo locks out instead of
granting; and **`adminUsers` is not writable from any client**, or an admin
could promote themselves. `parents/{uid}.role == 'admin'` still works, mapped
to `contentAdmin`, behind `allowLegacyParentRole` in `app.dart`.

**`moduleId` on `MediaAsset` is nullable.** The storage layer stays usable for
app-wide assets (splash art, Koala Guide audio). The "media belongs to a module"
rule is enforced in the admin upload path, which is where UC-19 scopes it.

**The admin panel borrows the parent dashboard's visual language, deliberately
(2026-08-26).** Both are grown-up screens, so the portal uses the same
grape→violet header gradient, the same lilac-outlined panel cards at an 18px
radius, and the same accent-washed tiles. Admin identity comes from *content* —
role labels, the shield icon, the menu — not from a separate colour scheme, so
the portal cannot drift from the app as the team restyles it.

Everything shared lives in `lib/views/admin/widgets/admin_theme.dart`, which
`admin_scaffold.dart` re-exports; a screen still needs only the one import.
**Restyle by editing that file, not by adding local one-off decorations** —
per-screen hex values are exactly what this replaced. If the team changes
`AppColors` or the dashboard's shapes, the panel should be re-checked against
them, since it is tracking that design rather than owning one.

Note this is a *theming* pass only. The charts and the wider UI/UX work the
project owner deferred are still deferred; §8 still lists them.

---

## 3. Caveats — read before trusting this

### 3.1 The Firebase admin path has never executed

`FirebaseAdminAuthRepository` and `FirestoreAdminStatsRepository` are **written
but never run against a real Firebase project.** Every verification was done in
demo mode (`--dart-define=USE_FIREBASE=false`).

This is untested code. The secondary-`FirebaseApp` initialization and the
`count()` aggregation queries are the highest-risk parts. **Test these before
any demo or release.**

Why it could not be tested here: Firebase project `little-learner-9d2f1` has
only an Android app registered (no web app), and this machine has no Android
SDK. See §5 and `docs/FIREBASE_ADMIN_SETUP.md`.

As of 2026-08-26 this also covers `AdminUserFirestoreService` and the
`adminUsers` rules. The demo-mode equivalents are tested; the Firestore reads
are not.

**Update — the first real run found a real bug. See §3.8.** Treat the rest of
this section as still live: one defect surfacing does not mean the others were
checked.

### 3.2 A published module can still have no levels

The UC-19 rule "each module must have at least one level" is enforced in
`AdminContentViewModel.publishModule`, **not** in `createModule`.

`createModule(isPublished: true)` can therefore still create a published module
with zero levels. Guarding creation was tried and reverted — a module has no
levels at the moment it is created, so it blocked authoring a module and its
first level in one session, which the existing tests show is the intended flow.

To close it: validate existing published modules, or show a warning badge in
the module list. Not a silent bug — just incomplete.

### 3.3 Demo mode does not persist, and its two stores have different lifetimes

- Parent accounts live in `InMemoryAuthRepository` — **wiped on page reload**.
- Child profiles live in SQLite → IndexedDB on web — **persist across reloads**.

This produced a real confusion during development: the dashboard showed child
profiles from earlier sessions next to a parent count that had reset.
`LocalAdminStatsRepository` now filters out profiles whose parent no longer
exists, so both numbers measure the same thing.

For a genuinely clean slate: Chrome DevTools → Application → Storage → Clear
site data.

### 3.4 The parent-dashboard admin button

Originally removed here for UC-18, then **re-added and restyled upstream**
(`profile_selection_page.dart` is now `parent_dashboard_page.dart`). The merge
kept the team's button but repointed it at the **admin login** instead of
dropping an authenticated parent into the dashboard, which would have
dead-ended at "Access Denied".

**If the client expects an admin to reach the portal without re-authenticating,
that conflicts with UC-18 and needs a decision.**

### 3.5 Content admins cannot see parent accounts

A deliberate least-privilege call, not an oversight: the parent account list
carries parent email addresses, so it is `superAdmin` only. If the team expects
content admins to see it, change `AdminRole.canViewParentAccounts` and the
`canReadParentAccounts()` rule together — the client and the rules must agree.

### 3.6 Eight tests fail, and they are not from this branch

`child_avatar_picker_test.dart` (4) and `onboarding_pages_widget_test.dart` (4)
fail with one root cause: a *"ListTile background color or ink splashes may be
invisible"* framework assertion in upstream's own UI.

**Verified pre-existing** by running both files against a clean checkout of
upstream `main`, where they fail identically. Most likely a Flutter version
difference — this machine is on 3.44.8. Left alone rather than changing the
team's UI on a guess.

### 3.7 An earlier defect worth not repeating

The first version of `InMemoryAdminStatsRepository` returned **hardcoded demo
numbers** (3 parents / 6 children / 18 quizzes) that never changed regardless of
app activity. It looked like a real repository and cost debugging time — the
symptom was mistaken for a Firebase sync problem.

Replaced by `LocalAdminStatsRepository`, which computes from live DAOs.
`InMemoryAdminStatsRepository` still exists for tests. **Do not wire it into the
app.** If a metric cannot be computed, surface that rather than inventing a
number.

### 3.8 The two-app split — the bug the first real run found

**Fixed 2026-08-26, but the shape of it is worth keeping.**

UC-18 puts the admin session on a **secondary `FirebaseApp`**
(`littleLearnersAdmin`) so admin sign-in cannot replace
`FirebaseAuth.instance.currentUser`. The consequence is not obvious: **every
admin Firestore _and Storage_ call must use that app too.**

Admin identity resolved on the secondary app, but statistics, content, media
and the koala guide all queried `FirebaseFirestore.instance` — the default app,
where the admin is not signed in. The rules evaluated `isAdmin()` against the
parent's uid, or none at all, and denied everything.

The failure is nastily misleading: **login succeeds**, the dashboard renders,
the role shows correctly — and then every screen fails with
`PERMISSION_DENIED: Missing or insufficient permissions`. It reads exactly like
undeployed rules or a bad console setup. It is neither. Before anyone
redeploys rules chasing a permission error, check *which app* the query is on.

Guarded structurally rather than by a test: `firestore` and `storage` are now
**required** constructor arguments on the admin repositories, so passing the
wrong instance is a compile error. `AdminFirebaseApp` owns the app and throws
rather than falling back to the default instance — a silent fallback is the bug.

A unit test could not have caught this; it needs a real project, a real admin
account and deployed rules. If a Firebase emulator suite is ever set up, this
is the first thing to point it at.

---

## 4. Already built but never called — do not rebuild

Originally audited 2026-08-05, **re-checked after the upstream merge on
2026-08-26**. Two gaps have since been closed by the team; the rest still
stand.

**Closed upstream — do not re-report:**

- `NotificationDeliveryRepository` is now wired. Upstream added
  `views/notifications/notification_center_page.dart` and
  `NotificationViewModel`, plus local scheduling via
  `flutter_local_notifications`.
- `ParentRemindersPage` is now reachable, from the notification centre.

The rest below is still complete, tested code that the running app never
reaches.

### 4.1 `BackendSyncCoordinator` is never invoked — highest priority

Constructed in `lib/app.dart` and registered as a Provider. **`syncNow()` is
called from nowhere.**

It is the connectivity-aware orchestrator with retry/backoff that implements
the client's stated key principle — *"online-first with offline learning… new
content is only updated when the internet is available."* **That principle is
therefore not implemented as designed.**

Sync does happen, but ad-hoc from viewmodels: profiles on
`ProfileViewModel.loadProfiles`, progress on level completion, content on admin
publish, leaderboard on load. No connectivity checks, no backoff, no
coordination.

This is the single highest-value gap in the app.

### 4.2 Two screens are still unreachable

Routed in `app_router.dart`, never navigated to (re-verified 2026-08-26):

| Screen | Note |
|---|---|
| `LeaderboardPage` | A leaderboard tab is embedded in the parent dashboard instead |
| `LearnerDetailPage` | Only reachable from `LeaderboardPage`, so transitively dead |

### 4.3 Backend with no UI

- **`AdminKoalaGuideRepository`** — full CRUD, Firestore repo, sync service and
  authorization wrapper, but **no admin screen** (still true on 2026-08-26).
  This is admin-domain work and the most obvious next piece of the panel.

---

## 5. Getting Firebase working

Required before the admin panel can be considered shippable (see §3.1).

1. Register a **web app** for `little-learner-9d2f1` in the Firebase console.
   *Requires the project owner's Google account — cannot be done from the code.*
2. `flutterfire configure` → generates `lib/firebase_options.dart`.
3. Pass `options: DefaultFirebaseOptions.currentPlatform` in
   `Firebase.initializeApp()` (`lib/main.dart`).
4. `firebase deploy --only firestore:rules` — **without this the parent-accounts
   and statistics screens return permission-denied.** Not a UI bug.
5. Drop `--dart-define=USE_FIREBASE=false`.

Also: `android/app/google-services.json` still uses the placeholder package
`com.example.little_learners`, which blocks any Play Store release.

---

## 6. Environment

Set up 2026-08-02 on Windows 11.

- Repo: `D:\Projects\lit-learners`
- Flutter SDK: `D:\dev\flutter` (3.44.8, Dart 3.12.2), on the user PATH.
  `pubspec.lock` pins **Flutter ≥3.38.4 / Dart ≥3.10.3**.
- Run in a browser:
  ```
  flutter run -d chrome --web-port 8080 --dart-define=USE_FIREBASE=false
  ```
- **No Android SDK installed** — `flutter build apk` will fail.
- On a fresh clone, regenerate the web SQLite worker:
  ```
  dart run sqflite_common_ffi_web:setup
  ```
  (`web/sqflite_sw.js` and `web/sqlite3.wasm` are committed so a clone runs
  without this; consider gitignoring them instead.)
- A white screen in the browser is usually a stale Flutter debug bootstrap, not
  a broken build. Hard-refresh (Ctrl+Shift+R) and use the Chrome window
  `flutter run` opened, not an old tab bound to a dead debug service.

**`file_picker` 11 removed `FilePicker.platform`** — `pickFiles` is now static.
Older tutorials will mislead you.

---

## 7. Verification status

| Check | Result |
|---|---|
| `flutter analyze` | No issues |
| `flutter test` | **290 passing, 8 failing** — all 8 pre-existing upstream, see §3.6 |
| `flutter build web` | Succeeds |
| Runs in Chrome, demo mode | Verified, no runtime exceptions |
| Runs against Firebase | **Never attempted** — see §3.1 |
| Runs on Android/iOS | **Never attempted** — no SDK on this machine |

**The theming pass was not visually reviewed on a phone.** It was checked in
Chrome at desktop width. The layouts are built from `Wrap`, `Expanded` and
`ListView` with no fixed widths, and the pill rows were introduced specifically
because the previous `ListTile` trailing rows overflowed on narrow screens — but
"should reflow" is reasoning, not a screenshot. Look at the dashboard hero
(three stats in a row) and the content rows on a real handset before signing
this off.

Intermediate commits are grouped as coherent thematic units for reviewability;
the **final branch state** is what was verified above.

The 8 failures were confirmed pre-existing by checking out upstream `main` in a
separate worktree and running the same two files there, where they fail
identically. Do not assume a green run means they were fixed — re-check against
`main` before attributing them to this branch.

---

## 8. Suggested next steps

1. **Register the Firebase web app and create the first `adminUsers` document**
   — `docs/FIREBASE_ADMIN_SETUP.md`. Nothing about the Firebase admin path can
   be trusted until it has run once.
2. **Wire `BackendSyncCoordinator`** (§4.1). Already built and tested;
   implements the principle the client called out as key.
3. **Add the Koala Guide admin screen** (§4.3) — backend complete, admin-domain.
4. Decide on the unreachable screens (§4.2): wire them up or delete them.
5. Investigate the 8 pre-existing test failures (§3.6) — likely a Flutter
   version mismatch between this machine and the team's.

Deferred by the project owner, explicitly *not* now:

- High-quality charts/graphics for the statistics screen.
- Overall UI/UX enhancement pass.

Also outstanding from an earlier analysis, unrelated to the admin panel: the app
targets ages 2–4 but is almost entirely text-driven — `ContentItem` has **no
image field** (`visualLabel` is a string like `'Three apples'` rendered as
text), and **88 referenced audio cue keys have no audio files**. There is no
localization infrastructure despite a full Urdu module.
