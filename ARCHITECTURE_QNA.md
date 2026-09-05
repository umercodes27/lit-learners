# Little Learners — Architecture & Design Defence (Q&A)

A panel-ready explanation of how this app is built, module by module, with the
reasoning behind each decision and the alternatives that were rejected.

Every answer points at the file that proves it, so a claim can be checked live.

**Project at a glance**

| Metric | Value |
| --- | --- |
| Platform | Flutter (Dart SDK ≥ 3.5), Android + iOS |
| Production code | 147 Dart files, ~24,300 lines in `lib/` |
| Test code | 56 test files, ~6,100 lines, **204 tests, all passing** |
| Layers | `models` (22) · `views` (28) · `viewmodels` (13) · `repositories` (21) · `services` (35) · `widgets` (11) · `core` (12) · `data` (3) |
| Backend | Firebase Auth + Cloud Firestore + Firebase Storage |
| Local store | SQLite (`sqflite`), schema v5, 9 tables |
| Third-party deps | 11 direct (`provider`, `sqflite`, `path`, `audioplayers`, `video_player`, `image_picker`, `cupertino_icons`, 4× `firebase_*`) |
| Learning modules | 8 (Math, English, Urdu, Video, Logic, Stories, Drawing, Tracing), 42 levels |

---

## Table of contents

1. [Product & scope](#1-product--scope)
2. [Core architecture](#2-core-architecture)
3. [Data flow end to end](#3-data-flow-end-to-end)
4. [Offline-first & synchronisation](#4-offline-first--synchronisation)
5. [Content pipeline](#5-content-pipeline)
6. [Drawing module](#6-drawing-module)
7. [Tracing module](#7-tracing-module)
8. [Parent marking & the scoring model](#8-parent-marking--the-scoring-model)
9. [Audio module](#9-audio-module)
10. [Parent vs child separation](#10-parent-vs-child-separation)
11. [Auth, onboarding & admin](#11-auth-onboarding--admin)
12. [Leaderboard & privacy](#12-leaderboard--privacy)
13. [Localisation, RTL & Urdu](#13-localisation-rtl--urdu)
14. [Reminders & notifications](#14-reminders--notifications)
15. [Koala Guide (guidance engine)](#15-koala-guide-guidance-engine)
16. [Testing strategy](#16-testing-strategy)
17. [Security](#17-security)
18. [Known limitations & future work](#18-known-limitations--future-work)
19. [Rapid-fire answers](#19-rapid-fire-answers)

---

## 1. Product & scope

### Q1.1 — In one paragraph, what is Little Learners?

An offline-first Flutter e-learning app for toddlers aged 2–4. A parent signs up,
reads a short manual, passes a readiness test, and creates up to three child
profiles. Each child gets an age-appropriate dashboard of learning modules
(Math, English, Urdu, Video, Logic, Stories, Drawing, Tracing). Levels unlock in
sequence, some end in a quiz, and finished work earns stars and a celebration.
Drawing and tracing work is graded by a parent behind a parental lock rather than
by the app. Parents also get progress reports, an opt-in anonymised leaderboard,
learning reminders, and — if their account is promoted to admin — a content
management dashboard with a draft/review/publish workflow.

### Q1.2 — Why toddlers? What does that constraint change technically?

Age drives most of the interaction design, and several architectural decisions
fall out of it:

| Age constraint | Technical consequence |
| --- | --- |
| Cannot read | Every card carries an audio cue key; the Koala Guide narrates context |
| Cannot type | The parental lock uses a keypad, not a password field |
| Small, imprecise fingers | Three chunky brush sizes instead of a slider (`DrawingWidth`); a 5.5 %-of-canvas tolerance band in tracing |
| Palm rests on screen | Canvas locks to a single pointer (`_activePointer`) so a palm cannot start a second stroke |
| Ability varies enormously year to year | Four "stages" derived from age (`AgeStageHelper`), and quizzes only appear at age 3+ |
| Cannot self-assess | Free drawing is graded by a human, not the app |
| Often used offline / on shared cheap devices | SQLite-first architecture, downloadable levels, sync as a background concern |

### Q1.3 — What is the "stage" concept?

`lib/core/utils/age_stage_helper.dart` maps age → stage: `≤1 → 1`, `2 → 2`,
`3 → 3`, `4+ → 4`. Stage is the single axis for content difficulty. Modules
declare `minStage`/`maxStage` (Tracing starts at stage 2 — following a dotted
line needs steadier hands than a one-year-old has), levels declare a `stage`, and
the leaderboard groups children by stage so a 4-year-old never out-ranks a
2-year-old. Using a derived stage instead of raw age means content is authored
against four buckets rather than a continuum.

---

## 2. Core architecture

### Q2.1 — What is the overall architecture?

**MVVM with a repository layer and manual constructor-injected dependencies.**
Five layers, strictly one-directional:

```
        ┌─────────────────────────────────────────────┐
 UI     │  views/  +  widgets/          (Flutter)     │  no business logic
        └───────────────┬─────────────────────────────┘
                        │ context.watch / context.read
        ┌───────────────▼─────────────────────────────┐
 State  │  viewmodels/   ChangeNotifier               │  screen state + orchestration
        └───────────────┬─────────────────────────────┘
                        │ abstract interfaces
        ┌───────────────▼─────────────────────────────┐
 Domain │  repositories/  (abstract + impls)          │  business rules
        └───────────────┬─────────────────────────────┘
                        │
        ┌───────────────▼─────────────────────────────┐
 Data   │  services/local (SQLite DAO+mapper)         │
        │  services/remote + services/firebase        │
        │  services/sync, services/audio, /tracing    │
        └───────────────┬─────────────────────────────┘
                        │
        ┌───────────────▼─────────────────────────────┐
 Model  │  models/   plain immutable Dart classes     │  no framework imports*
        └─────────────────────────────────────────────┘
```

\* except where a model genuinely is a UI value — `DrawingStroke` holds `Offset`
and `Color`, `CanvasWork` holds a `Size`.

The rule that keeps it honest: **a view never touches a repository, and a
repository never touches Flutter.** Views talk to view models; view models talk
to repository *interfaces*; the concrete implementation is chosen once, in
`lib/app.dart`.

### Q2.2 — Why MVVM and not BLoC, Riverpod, Redux or Clean Architecture?

This is the most likely question, so here is the full comparison:

| Option | Why not chosen |
| --- | --- |
| **BLoC / flutter_bloc** | Every interaction becomes an Event class + a State class. For screens that are mostly "show a card, tap a button, move to the next card", that is 3× the file count for no extra safety. It shines with complex concurrent event streams; this app has almost none. |
| **Riverpod** | Genuinely better compile-time safety than Provider, but it is a second mental model on top of Flutter's own, and the team benefit was not worth the migration risk mid-project. Provider is the officially-recommended baseline and is a thin wrapper over `InheritedWidget`. |
| **Redux / MobX** | Global single-store or reactive-proxy models add ceremony that a 13-view-model app does not repay. |
| **Full Clean Architecture** (entities / use-cases / interactors) | The use-case layer would be a pass-through for ~90 % of operations. The repository interfaces already give the testability that use cases are usually introduced to provide. |
| **setState only** | Would work for one screen, but progress, content and sync are shared across screens; the state has to outlive any single widget. |

**MVVM + Provider was chosen because:**

1. `ChangeNotifier` is in the Flutter SDK — zero dependency for state management
   beyond the 4 kB `provider` package.
2. View models are plain Dart objects, so they are unit-testable without any
   widget pumping. 13 of the 56 test files test view models directly.
3. It maps cleanly onto how the screens actually behave (form-like, request →
   state → rebuild).
4. It is the pattern the Flutter documentation itself recommends, which matters
   for a project that has to be handed over.

**Honest trade-off to volunteer before they ask it:** `ChangeNotifier` broadcasts
one undifferentiated "something changed" signal, so a widget listening to
`LearningViewModel` rebuilds when any part of it changes. This is mitigated by
keeping view models small and single-purpose (`QuizViewModel` only knows about
one quiz; `LevelActivityViewModel` only about one level) rather than one god
object.

### Q2.3 — How is dependency injection done? Why not `get_it`?

All wiring happens once, at the top of `lib/app.dart:70-215`, as file-level
finals, then exposed through a `MultiProvider` (`lib/app.dart:222-299`). The
critical line is:

```dart
bool get _firebaseEnabled => AppConfig.useFirebase && Firebase.apps.isNotEmpty;

final AuthRepository _authRepository = _firebaseEnabled
    ? FirebaseAuthRepository(...)
    : InMemoryAuthRepository();
```

Every backend-touching dependency has this shape: a **Firebase implementation and
an in-memory implementation behind the same interface**, selected by one flag.
That single pattern gives three things at once:

- The whole app runs with `--dart-define=USE_FIREBASE=false` for demos, offline
  development, and when the backend is down.
- Tests construct the in-memory implementation directly, so no test needs a
  Firebase emulator or network.
- If the backend were ever swapped (Supabase, a REST API), only the
  `services/firebase/` folder and this wiring block change.

`get_it` was not used because a service locator hides dependencies inside method
bodies (`getIt<Foo>()` anywhere), which makes a class's real dependencies
invisible from its constructor. Constructor injection plus one wiring file keeps
the dependency graph readable in a single screen of code and makes an
unsatisfiable dependency a compile error rather than a runtime crash.

### Q2.4 — How does routing work, and why `onGenerateRoute` instead of go_router?

Named routes are declared as constants in `lib/core/routing/route_names.dart`
(23 routes) and built centrally by `AppRouter.generateRoute`
(`lib/core/routing/app_router.dart:105`). Arguments are passed as **typed
argument classes** (`QuizArgs`, `ParentMarkingArgs`, `CelebrationArgs`,
`VideoPlayerArgs`, `ProfileEditArgs`, `ParentalLockArgs`) rather than raw maps,
so a wrong argument is a compile-time or immediate cast error, not a silent
`null`.

One subtlety worth pointing out, because it is a real bug that was fixed:
routes that **return a value** must be built with a matching `Route<T>`, because
`Navigator.pushNamed<T>` casts the result. That is why the parental lock and the
marking page are special-cased before the main `switch`
(`lib/core/routing/app_router.dart:109-125`):

```dart
if (settings.name == RouteNames.parentalLock) {
  return MaterialPageRoute<bool>(...);        // pops true/false
}
if (settings.name == RouteNames.parentMarking) {
  return MaterialPageRoute<ParentMark>(...);  // pops the grade
}
```

`go_router` was not adopted because the app has no deep links, no web URL
strategy, and no nested shell navigation — its main selling points. Flutter's
built-in Navigator 1.0 API covers the whole flow, with no extra dependency.

### Q2.5 — Why so many `abstract class` repositories if there is only one real implementation each?

There are almost always two (Firebase + in-memory), and the abstraction pays for
itself in three ways:

1. **Tests.** `test/leaderboard_repository_test.dart`,
   `test/progress_repository_test.dart` etc. run against fakes with no I/O.
2. **Decorators.** `AuthorizedAdminContentRepository`
   (`lib/repositories/admin_authorization_repository.dart:57`) wraps *any*
   `AdminContentRepository` and enforces an admin check on every method before
   delegating. That cross-cutting rule is written once, not repeated in six
   methods of a concrete class.
3. **Backend independence.** `CachedProgressRepository` knows nothing about
   Firestore; it talks to a `ProgressDao`. Firestore only ever appears behind
   `services/firebase/`.

---

## 3. Data flow end to end

### Q3.1 — Walk me through what happens when a child completes a level.

Take the most complex case — a tracing level with a quiz:

```
1.  TracingLevelView  (view)
      child traces glyph → DrawingCanvas captures pointer events
      → DrawingCanvasController accumulates DrawingStroke objects
      → each finished page is captured as CanvasWork (geometry, not an image)

2.  "Show a grown-up"  → LevelPlayerPage._markCanvasWork()
      → Navigator.push(parentalLock)        pops bool
      → if unlocked: Navigator.push(parentMarking, work)   pops ParentMark

3.  ParentMarkingPage
      runs TraceScorer over the pages → shows an accuracy % as advice only
      parent picks one of 4 grades → pops ParentMark (45 / 70 / 85 / 100)

4.  Back in LevelPlayerPage
      mark fails?  → dialog + LevelActivityViewModel.restart()  (fresh page)
      mark passes? → _complete(score: mark.score)

5.  Quiz gate:  level has questions AND child.age >= 3
      → pushReplacement(quiz, QuizArgs(levelId, parentMark: score))
      → QuizViewModel.combineWithParentMark → (parentMark + quizPercent) / 2

6.  LearningViewModel.completeLevel(childId, level, score)
      → CachedProgressRepository.completeLevel()
           computes stars from score vs passingScore
           writes LevelProgress with isSynced = false
      → SqfliteProgressDao.upsert()   ← SQLite, the source of truth
      → ProgressSyncService.syncNow() ← best-effort push to Firestore
      → reload progress, notifyListeners()

7.  CelebrationPage  ← stars + score
```

The important property: **step 6 succeeds with no network.** The write lands in
SQLite and is flagged unsynced; the Firestore push is a separate, failable step.
A child in a car with no signal still earns their stars.

### Q3.2 — Where does the app decide *anything*? Draw me the responsibility line.

| Concern | Lives in | Never lives in |
| --- | --- | --- |
| "Is this level unlocked?" | `LearningViewModel.isLevelUnlocked` | the view |
| "How many stars?" | `CachedProgressRepository._starsFor` | the view or the view model |
| "Can this parent create a 4th child?" | `CachedChildProfileRepository.createProfile` throws `ProfileLimitException` | the form |
| "Is this trace good?" | `TraceScorer` (advice) + the parent (decision) | anywhere else |
| "Is this user an admin?" | `AuthAdminAuthorizationRepository` **and** `firestore.rules` | the UI alone |
| "Which guide message shows here?" | `SeededKoalaGuideRepository.getMessage` | the screen |

The pattern: **views render and route; view models hold screen state; rules live
in repositories.**

### Q3.3 — Why is progress read back from the DAO after every write instead of mutating the in-memory list?

`LearningViewModel.completeLevel` (`lib/viewmodels/learning_viewmodel.dart:129`)
writes, syncs, then re-reads `getProgressForChild`. This costs one cheap indexed
SQLite query and guarantees the in-memory list can never drift from the database
— including the case where the sync pulled a *newer* record from another device
in between. Correctness over micro-optimisation, on a table that holds tens of
rows per child.

---

## 4. Offline-first & synchronisation

### Q4.1 — What does "offline-first" mean here concretely?

It means **SQLite is the source of truth for the app, and the backend is a
replica**, not the other way round. Reads never wait on the network. Writes
always go to SQLite first with `isSynced = 0`, and a sync service later pushes
them.

Schema: `lib/services/local/db_schema.dart`, version 5, 9 tables —
`app_meta`, `child_profiles`, `sync_outbox`, `modules`, `levels`,
`content_items`, `quiz_questions`, `video_lessons`, `level_progress`, plus 10
indexes. Migrations are additive and versioned (`db_helper.dart:23-44`): v2 added
the outbox, v3 the content tables, v4 progress, v5 the meta table. An existing
install upgrades without losing data.

### Q4.2 — How are updates pushed? Explain the outbox pattern.

Two different mechanisms, because updates and deletes have different failure
modes:

**Upserts — the dirty-flag ("`isSynced`") pattern.** Every syncable row carries
`isSynced INTEGER NOT NULL DEFAULT 0`, and both `child_profiles` and
`level_progress` have an index on it. `SyncService.syncNow` asks the DAO for
`getUnsynced()`, pushes each row, and marks it synced on success
(`lib/services/sync/sync_service.dart:46-55`). The row itself carries the state,
so nothing extra is stored.

**Deletes — the outbox pattern.** A deleted row cannot carry a dirty flag,
because it is gone. So `CachedChildProfileRepository.deleteProfile` enqueues a
`SyncOutboxItem` *before* deleting locally
(`lib/repositories/child_profile_repository.dart:90-96`):

```dart
await _syncOutboxDao.enqueue(
  SyncOutboxItem.childProfileDelete(parentId: parentId, childId: childId),
);
await _profileDao.delete(parentId: parentId, childId: childId);
```

The outbox row holds `entityType`, `operation`, a JSON payload, `attemptCount`
and `lastError`. `SyncService._handleOutboxItem` replays it against the backend
and only then marks it completed. Delete an offline child, close the app, come
back a week later on Wi-Fi — the delete still propagates.

### Q4.3 — How do you resolve conflicts between the device and the server?

**Last-write-wins on `updatedAt`, biased towards unsynced local work.** In both
pull paths (`sync_service.dart:96-106` and `progress_sync_service.dart:51-63`)
the rule is identical:

```dart
if (existing != null &&
    !existing.isSynced &&                       // local edit not yet pushed
    existing.updatedAt.isAfter(remote.updatedAt)) {
  continue;                                     // keep local, skip the remote row
}
await dao.upsert(remote.copyWith(isSynced: true));
```

So a remote record only overwrites local data when the local copy is either
already synced or genuinely older. The push always runs before the pull, and the
pull is skipped entirely if any push failed (`failedItems == 0` guard), so a
failed upload can never be clobbered by a stale download in the same pass.

**Why LWW and not CRDTs / operational transforms / vector clocks?** The data has
no concurrent-edit semantics worth preserving: a child's level score is written
by one device at a time, and profiles are edited by one parent. LWW is the right
strength of tool. The one place naive LWW *would* be wrong — deletes — is handled
by the outbox instead of by timestamps.

**Known limitation, stated up front:** timestamps come from `DateTime.now()` on
the device, so a device with a badly wrong clock could win or lose a conflict it
should not. Firestore's `serverTimestamp` is already written as a separate
`syncedAt` field (`firestore_progress_remote_data_source.dart`), which is the
hook for moving to server-authoritative ordering later.

### Q4.4 — Why is there a `SyncOrchestrator` on top of the individual sync services?

Because "sync everything" is a different concern from "sync profiles". The
orchestrator (`lib/services/sync/sync_orchestrator.dart`) takes a list of named
`SyncTask`s and adds three cross-cutting behaviours:

1. **Connectivity gating** — if offline, every task is reported
   `skippedOffline` instead of being attempted and failing.
2. **Exponential backoff per task** — a failed task records `attemptCount` and a
   `nextRetryAt`; the backoff doubles (`1 << (attemptCount - 1)`) from 30 s and
   caps at 10 minutes (`_backoffFor`, line 160). A task in backoff is reported
   `skippedBackoff` rather than being hammered.
3. **A structured report** — `SyncOrchestrationReport` says exactly which tasks
   succeeded, failed, or were skipped and why.

`BackendSyncCoordinator` composes the actual task list — profiles, progress,
content, koala guide, leaderboard — from whichever ids it was given
(`backend_sync_coordinator.dart:35-80`). Backoff state is keyed by task *name*,
so a failing leaderboard push cannot slow down content sync.

**Why is `AlwaysOnlineConnectivityStatusProvider` the default?** Honest answer:
the `ConnectivityStatusProvider` interface exists and is fully exercised by
tests, but no real connectivity plugin is wired in yet, so the production
provider always reports online and the app relies on individual task failures
plus backoff. Adding `connectivity_plus` is a one-class change with no other
edits — that is precisely why the seam was built.

---

## 5. Content pipeline

### Q5.1 — Where does learning content come from?

Three sources, in a defined precedence:

1. **Bundled seed content** — `lib/data/seed_content.dart` (1,824 lines):
   8 modules, 42 levels, their content cards, quiz questions and video lessons,
   written as `const` Dart. Ships inside the app, so a brand-new install has a
   full curriculum with no network.
2. **The local SQLite cache** — seeded from (1) on first launch; this is what
   the app actually reads.
3. **Remote published content** — admin-authored modules/levels in Firestore.
   `ContentSyncService.syncNow` pulls the published bundle and calls
   `replaceContent`, which overwrites the cache
   (`lib/services/sync/content_sync_service.dart:30-51`).

### Q5.2 — The database is seeded once. How do you ship new bundled content to an existing install?

This is a genuinely non-obvious problem and it has an explicit solution: a
**content revision stamp**.

`lib/data/seed_content.dart:15` declares
`const bundledContentRevision = '2026-08-07-parent-marked-canvas';`
and `app_meta` stores which revision the database was seeded with. On first read,
`CachedContentRepository._ensureSeeded`
(`lib/repositories/content_repository.dart:75-98`) does:

```dart
if (!hasModules)                             → seedContent(...)      + store stamp
else if (storedRevision != contentRevision)  → replaceContent(...)   + store stamp
```

Without this, a level added to the bundle would never appear on a device that had
already run the app — a silent, very expensive class of bug.

`replaceContent` (`content_dao.dart:150`) is careful: it reads the set of
already-downloaded level ids first, deletes and re-inserts content inside a
**single transaction**, and restores the downloaded flags. Level progress lives in
its own `level_progress` table keyed by `(childId, levelId)`, so it is untouched.
Net effect: content updates, nothing the child earned is lost.

`test/content_revision_test.dart` (12 tests) locks this in — including
"reinstalling the bundle keeps levels the parent downloaded".

### Q5.3 — What is `isBundled` vs `isDownloaded`?

`LearningLevel.isAvailableOffline => isBundled || isDownloaded`
(`lib/models/learning_level.dart:46`). Bundled levels ship in the app;
non-bundled levels (heavier ones — video) must be explicitly downloaded before
they can be played. `LearningViewModel` turns this into three UI states:
`canOpenLevel`, `canDownloadLevel`, and a `lockReasonFor` string. Note the
deliberate detail in `video_learning_page.dart:156-158` — a downloadable level is
**not** covered by the lock overlay, because covering it would hide the very
download button the parent needs.

### Q5.4 — Why is content authored as Dart `const` rather than JSON in assets?

Type safety and compile-time validation. A malformed level in JSON is a runtime
crash on a toddler's device; a malformed level in Dart does not compile. It also
means the content is greppable, diffable in code review, and directly testable —
`content_revision_test.dart` asserts things like "every tracing card carries a
single glyph" and "tracing quizzes only ask about glyphs the level traced"
against the real bundle. The cost is that a non-developer cannot edit it, which
is exactly what the admin CMS + Firestore path is for.

---

## 6. Drawing module

### Q6.1 — Which approach did you use for drawing, and why not the alternatives?

**Approach: vector stroke capture + `CustomPainter` rendering. Strokes are stored
as geometry — a list of points with a tool, colour and width — never as pixels.**

Rejected alternatives, and why:

| Alternative | Why rejected |
| --- | --- |
| **Bitmap / pixel buffer** (draw into an `Image`, blit it) | Once a stroke is rasterised it cannot be undone, rescaled, or re-rendered. Undo would need a full-resolution snapshot per stroke — megabytes per level. It also kills the thumbnail feature: the parent marking screen shows three full-screen pages side by side at 150 px wide. With geometry that is free; with bitmaps it is resampling. |
| **`GestureDetector` with pan callbacks** | `onPanUpdate` gives no pointer id and no pressure, so a palm touch and a finger are indistinguishable and pressure-sensitive tools are impossible. `Listener` with raw `PointerEvent`s gives `event.pointer`, `event.pressure`, `pressureMin`, `pressureMax`. |
| **A third-party drawing package** (`flutter_drawing_board`, `scribble`) | The tracing scorer needs to rasterise *exactly what the child saw* into an offscreen mask. That requires owning the paint code. A package would have forced either a divergent second renderer (scores that disagree with the drawing) or a fork. |
| **`RepaintBoundary.toImage()` to save work** | Async, produces a PNG, loses resolution independence, and needs image encoding for something that is a few hundred floats. |
| **SVG / `Path` objects only** | Loses per-point pressure, which the brush and pencil use. |

### Q6.2 — Explain the drawing data model.

`lib/models/drawing_stroke.dart`:

- `DrawingTool` — `pen, pencil, brush, highlighter, eraser`. An extension gives
  each tool a `widthFactor` (pencil 0.55 → highlighter 2.6), an `opacity`
  (highlighter 0.3), a `strokeCap` (square for the highlighter, round otherwise)
  and `respondsToPressure` (brush and pencil only).
- `DrawingWidth` — three fixed sizes (6 / 12 / 22 logical px). **Three chunky
  buttons, not a slider**, because a toddler cannot operate a slider.
- `DrawingStroke` — `tool`, `color`, base `width`, `List<Offset> points`, and a
  **parallel** `List<double> pressures`.

The design note that matters: *the tool only changes how a stroke is painted; the
captured geometry is identical.* That is what allows `scaled(factor)` and
`copy()`, and what lets the scorer re-render the same strokes as a flat mask.

### Q6.3 — How does the controller work, and why is it separate from the view models?

`DrawingCanvasController` (`lib/viewmodels/drawing_canvas_controller.dart`) is a
`ChangeNotifier` holding committed strokes, an active stroke, a redo stack, and
the current tool/colour/width. It is deliberately **not** part of
`LevelActivityViewModel`, because the exact same canvas is reused by free drawing
and by tracing, which have different level semantics but identical canvas
behaviour. Tracing simply constructs it with a different tool set (no
highlighter) and a thicker default:

```dart
DrawingCanvasController(
  width: DrawingWidth.large,
  availableTools: const [pen, pencil, brush, eraser],
)
```

Four details worth defending:

1. **A stroke is only committed on pointer-up.** `beginStroke` puts it in
   `_activeStroke`; `strokes` returns committed + active. So the in-progress line
   is visible but undo cannot half-remove it.
2. **Point thinning** — `extendStroke` drops any sample closer than
   `√1.5 ≈ 1.22 px` to the previous one (`drawing_canvas_controller.dart:99-102`).
   Fewer points means a smoother curve *and* a cheaper repaint; a 120 Hz digitiser
   otherwise floods the list with near-duplicates.
3. **Redo is cleared on a new stroke** — standard editor semantics; a branch in
   history is discarded.
4. **`hasInk` ignores eraser strokes** (`inkStrokeCount`), so a page that was
   drawn on and then completely erased correctly counts as blank and the "done"
   button stays disabled.

### Q6.4 — How is the ink actually rendered? Explain the smoothing.

`StrokePainting.pathFor` (`lib/widgets/drawing/stroke_painter.dart:14-37`)
converts points to a `Path` using **quadratic Bézier segments through the
midpoints of consecutive samples**: each raw point becomes a control point, each
midpoint an anchor.

```dart
for (var i = 1; i < points.length - 1; i++) {
  final midpoint = (points[i] + points[i + 1]) / 2;
  path.quadraticBezierTo(points[i].dx, points[i].dy, midpoint.dx, midpoint.dy);
}
```

Why this and not `lineTo`: straight segments between touch samples produce
visible polygonal kinks on curves at toddler drawing speeds. Why not Catmull-Rom
or cubic splines: those need a lookahead of two points and can overshoot,
producing loops on sharp direction changes — visibly wrong on a letter. The
midpoint-quadratic method is the standard signature-capture technique: C¹
continuous, no overshoot, one pass, no tuning parameters.

Single points are a special case (`isDot`) and are drawn as a filled circle,
because a zero-length path with a round cap renders nothing on some backends —
so a child who just taps the screen would otherwise see no dot at all.

### Q6.5 — How does the eraser work?

`BlendMode.clear` inside a saved layer. `paintStrokes` wraps the whole stroke
list in `canvas.saveLayer(bounds, Paint())` and the eraser paint sets
`blendMode = BlendMode.clear` (`stroke_painter.dart:51-57, 90-91`).

Without the layer, `BlendMode.clear` composites against the surface and paints
**black**, which is a classic Flutter canvas bug. The layer is what gives the
eraser something to erase *from*. The cost is one offscreen layer per repaint,
which is why both the background and the ink live inside their own
`RepaintBoundary` in `DrawingCanvas` (`drawing_canvas.dart:50-65`).

An alternative — filtering erased strokes out of the list geometrically
(hit-testing every point against the eraser path) — was rejected as O(points ×
eraser samples) per frame, and it cannot partially erase a stroke.

### Q6.6 — How is pressure handled?

`DrawingCanvas._normalizedPressure` normalises the raw value into 0..1 using the
device's own reported `pressureMin`/`pressureMax`, and returns `1` when the
device reports no usable range (`drawing_canvas.dart:113-117`) — so a
non-pressure-sensitive screen simply gets a constant full-weight stroke instead
of a divide-by-zero or a paper-thin line.

`DrawingCanvasController._widthFor` then applies it **only to tools that opted
in**: `width * (0.75 + pressure * 0.5)`, i.e. a ±25 % swing. Pen, highlighter and
eraser are pressure-independent by design — a pen that thins out when a toddler
presses lightly reads as a broken pen.

### Q6.7 — How is repaint performance controlled?

`StrokeCanvasPainter.shouldRepaint` compares a single integer, not the stroke
list (`stroke_painter.dart:135-137`):

```dart
bool shouldRepaint(old) => old.revision != revision;
```

The controller increments `_revision` in `_bump()` on every mutation. Comparing
two ints is O(1); comparing two lists of strokes each holding hundreds of
`Offset`s would be O(n) *per frame* — the comparison would cost more than the
paint. The background (the dotted glyph) is a separate `CustomPaint` in its own
`RepaintBoundary`, so drawing a line never repaints the guide.

### Q6.8 — Why does the drawing level keep one page across prompts, but tracing uses one page per letter?

Because the content is written that way, and the code follows the content.
Drawing levels are authored as steps that build a single picture — "draw the
sky", then "draw a house under the sky" — so wiping the page between steps would
destroy the work. Tracing levels are one glyph per card, and a parent needs to
see *every* letter, not just the last one.

Hence: `DrawingLevelView` never clears, and instead tracks an **ink baseline** —
the stroke count when the current prompt started — so each step still requires
its own fresh marks and cannot be completed by pointing at what was already on
the page (`canvas_level_view.dart:50-53, 98-103`). `TracingLevelView` captures the
finished page into `Map<int, CanvasWork> _captured` before clearing for the next
glyph (`canvas_level_view.dart:262-266`).

---

## 7. Tracing module

### Q7.1 — How do you render the dotted letter a child traces over?

**Without any per-glyph vector data.** The guide is generated from the font
itself, in three layers (`lib/widgets/tracing/trace_guide_painter.dart`):

1. A very pale filled glyph (`alpha 0.08`) so the shape is always readable — the
   "ghost".
2. The **stipple**: the solid glyph painted at `alpha 0.55` inside a
   `saveLayer`, then a full-canvas rectangle with a circular hole at every grid
   point, drawn with `BlendMode.clear` and `PathFillType.evenOdd`. Punching the
   gaps out of the glyph leaves exactly the dots.
3. A thin stroked outline (1.4 px) that defines the edges.

```dart
canvas.saveLayer(bounds, Paint());
glyphLayout.paint(canvas, color: accent.withValues(alpha: 0.55));
canvas.drawPath(_gapMask(bounds, spacing, radius),
                Paint()..blendMode = BlendMode.clear);
canvas.restore();
```

Dot spacing adapts to canvas size (`shortestSide / 24`, clamped 9–18 px) so the
guide looks the same on a phone and a tablet.

**Why this and not hand-authored dotted paths per letter?** Because it scales to
any glyph in any script for free. Hand-authoring would mean drawing 26 English
letters × cases, 10 digits, and ~38 Urdu Nastaliq letterforms — Nastaliq being
cursive and context-sensitive, which is where hand-authoring gets genuinely hard.
Deriving the guide from the font means adding a new glyph is adding one string to
`seed_content.dart`.

### Q7.2 — How do you fit a glyph to the canvas? Why is that hard?

Because **a `TextPainter`'s box is much bigger than the letter inside it.** The
box includes font ascent and descent, and Nastaliq is extreme about this — its
boxes are enormously taller than the visible ink. Fitting by the layout box
leaves the letter small and off-centre, which for a tracing app means a child
tracing in the wrong part of the screen.

`TraceGlyph` (`lib/services/tracing/trace_glyph.dart`) solves it empirically:

1. Render the glyph once at a reference size (140 pt) into an offscreen image.
2. Scan the alpha channel for the true ink bounding box (`_inkBounds`, threshold
   16).
3. Because font rendering scales linearly, that box-to-ink ratio holds at
   **every** size — so the measurement is taken once per `font|glyph` and cached
   in a static map (`_metricsCache`).
4. Scale the ink to fill 74 % of the canvas (`defaultFillRatio`), taking the
   smaller of the width and height ratios so it never overflows, then back the
   ink offset out of the painter origin so the *ink*, not the box, is centred:
   `origin = inkTopLeft - (metrics.inkRect.topLeft * scale)`.

The result is a `TraceGlyphLayout` — glyph, font, font size, paint origin, ink
rect in canvas coordinates, text direction — which is the single object shared by
the painter, the scorer and the saved `CanvasWork`. That shared object is why the
guide the child saw, the mask the scorer measures, and the thumbnail the parent
reviews are guaranteed to be the same shape.

`TraceGlyph.resolve` is async (it rasterises), so `TracingLevelView` schedules it
in a `addPostFrameCallback` rather than inside `build`, and guards the result
against a stale size/glyph before calling `setState`
(`canvas_level_view.dart:359-381`).

### Q7.3 — How does the tracing scorer work? This is the algorithmic core.

`lib/services/tracing/trace_scorer.dart`. **Approach: rasterise the guide and the
child's ink into alpha masks at reduced resolution and compare them pixel by
pixel, on two independent axes.**

Four masks are produced (all via `_rasterize`, which records a picture, converts
to an image, and keeps only the alpha channel):

| Mask | Content |
| --- | --- |
| `target` | the glyph, filled |
| `tolerant` | the glyph filled **plus** a fat outline of width `band × 2` — the letter grown outward by the tolerance |
| `user` | the child's strokes, painted as a flat white mask (`asMask: true`) |
| `reach` | the child's strokes **dilated** by `shortestSide × 0.03 × 2` |

Then a single pass over the pixels yields two ratios:

```
coverage  = |target ∩ reach| / |target|     "did they trace the WHOLE letter?"
precision = |user ∩ tolerant| / |user|      "did they stay ON the letter?"
```

Each is normalised against calibrated anchors, then combined:

```dart
coverageScore  = clamp(coverage / 0.82)
precisionScore = clamp((precision - 0.55) / (0.93 - 0.55))
score = 100 × coverageScore^0.55 × precisionScore^0.45
```

### Q7.4 — Why two measures instead of one?

Because each catches a failure the other is blind to:

- **Coverage alone** → colouring the entire page black scores 100 %.
- **Precision alone** → a single 2 mm dot placed on the letter scores 100 %.

Requiring both is what makes the score mean "traced the letter".

### Q7.5 — Why a weighted *geometric* mean rather than a weighted sum?

Because a sum lets one axis buy off the other. With
`0.55·coverage + 0.45·precision`, a page-filling scribble (coverage ≈ 1.0,
precision ≈ 0.5 → 0) still scores 55 — a pass on most levels. The geometric mean
`c^0.55 · p^0.45` goes to **zero** if either factor is zero, so a trace has to be
both complete and on the letter. That is stated explicitly in the code comment at
`trace_scorer.dart:145-147`, and `test/trace_scorer_test.dart` pins it with
"drawing away from the letter scores badly".

### Q7.6 — Justify each magic number.

| Constant | Value | Justification |
| --- | --- | --- |
| `fullCoverage` | 0.82 | Toddler fingers never fill a glyph completely. Demanding 100 % would make full marks unreachable, so 82 % of the letter counts as complete. |
| `minPrecision` | 0.55 | Colouring the whole page in lands near 0.5, so useful precision starts just above it. Grading precision from 0 would score a scribble as a decent attempt. |
| `fullPrecision` | 0.93 | Honest tracing lands almost entirely inside the tolerance band, so the useful range is narrow and near the top. |
| `defaultToleranceRatio` | 0.055 | How far outside the letter a line may stray, as a fraction of the canvas's shortest side — ~5.5 %, roughly a toddler fingertip. Being a *ratio*, it is device-independent. |
| `coverageDilationRatio` | 0.03 | Coverage is measured against a slightly fattened copy of the child's ink, so a careful line with the thin pencil scores like the same line with the fat brush. It grades *where* they drew, not *what tool* they picked. |
| `_maxRasterSide` | 260 px | ~60 k pixels to walk instead of a full-resolution canvas. Plenty of detail to grade a letter; ~10× cheaper than full size. |
| `_alphaThreshold` | 24 | Ignores anti-aliasing fringe so a feathered edge is not counted as ink. |
| weights | 0.55 / 0.45 | Coverage weighted slightly higher: finishing the letter is the primary skill being taught; neatness is secondary at this age. |

### Q7.7 — Why raster comparison and not the "obvious" alternatives?

| Alternative | Why not |
| --- | --- |
| **Point-to-path distance** (nearest-point on an authored stroke path) | Needs per-glyph authored stroke paths — the exact thing being avoided. Also has no natural notion of *coverage*: it cannot tell "traced half the letter carefully" from "traced all of it carefully". |
| **DTW / `$1` gesture recogniser** | These match *sequence and direction*. A child who traces "A" bottom-up, or in three separate strokes in a different order, produces a correct-looking letter that DTW rejects. Penalising stroke order at age 3 is pedagogically wrong. |
| **ML classifier (CNN / TFLite)** | Answers a different question — "does this look like an A?" — not "did you follow this guide?". It would need a labelled toddler-handwriting dataset, add ~10 MB of model to the APK, and be unexplainable to a parent. The rubric here can be stated in one sentence. |
| **Comparing the two `Path` objects geometrically** | Path–path intersection area is not available in Flutter's API and is expensive to implement correctly for self-intersecting toddler scrawl. |
| **`Path.combine(intersect)` + area** | Flutter has no path-area primitive; you would end up rasterising anyway. |

The raster approach is **glyph-agnostic (English, digits and Urdu Nastaliq use
identical code), stroke-order agnostic, explainable, dependency-free, and shares
its renderer with the live canvas** — so what the child sees is literally what
gets measured (`StrokePainting.paintStrokes(..., asMask: true)`).

### Q7.8 — Where does the scorer actually get used?

Deliberately, **as advice only.** `ParentMarkingPage._measureTracing`
(`lib/views/marking/parent_marking_page.dart:44-62`) runs the scorer over every
page, averages the scores, and shows one line:

> "*87 % of the line landed on the dots. This is only a measurement to help you
> decide — your mark is what counts.*"

The grade that enters the progress pipeline is the parent's. See section 8 for
why.

---

## 8. Parent marking & the scoring model

### Q8.1 — Why is drawing graded by a parent instead of by the app? Isn't that a cop-out?

No — it is the one place where the honest engineering answer is "software cannot
do this well, and pretending otherwise harms the child."

The reasoning, as written in `lib/models/parent_mark.dart:3-13`:

> Canvas work is the one activity the app does not mark itself: it cannot tell a
> careful house from a scribbled one, and a toddler's best effort is a thing a
> parent recognises and software does not.

Concretely:

- **Free drawing has no ground truth.** "Draw your family" has no target mask.
  There is nothing for a scorer to compare against.
- **A wrong automatic score is worse than none.** Telling a 3-year-old their
  drawing failed is a bad outcome that no amount of tuning eliminates.
- **It converts a weakness into a feature.** Early-years pedagogy wants an adult
  looking at the work with the child. The marking screen is titled "Look at the
  page together, then choose a mark."
- **Tracing *can* be measured**, and it is — but the measurement is offered to
  the parent as a hint rather than imposed, because tracing quality at age 3 is
  partly about effort and grip, which a pixel count does not see.

This is defensible as a *design* decision, not a gap: the scorer exists, works,
and is tested — it is simply positioned as decision support.

### Q8.2 — Explain the `ParentMark` scale. Why four values, and why those numbers?

```dart
enum ParentMark { needsPractice, goodTry, greatWork, perfect }
//                     45            70          85         100
//  stars:              0             1           2          3
```

Two invariants drive the numbers, and both are enforced by tests
(`test/parent_marking_test.dart`):

1. **Exactly one grade fails, on every canvas level in the app.** Canvas levels
   have passing scores of 50–70 (drawing: 60/65/70; tracing: 50/60/70), so 45
   fails all of them and 70 passes all of them. A parent never has to reason
   about which level they are on.
2. **Each grade is worth exactly one more star than the last**, and the stars
   come out of the *existing* progress rule
   (`CachedProgressRepository._starsFor`: `<passing → 0`, `≥90 → 3`,
   `≥75 → 2`, else `1`). 45 → 0, 70 → 1, 85 → 2, 100 → 3. The mapping is
   verified rather than duplicated — `test/parent_marking_test.dart` asserts
   "the promised stars match the progress rules".

Four options because that is about the resolution a parent can apply
consistently; a 1–10 scale would be noise. And crucially, the grade maps onto the
**same 0–100 scale every other activity reports**, so stars, reports, the
leaderboard and the unlock rules need no special case for canvas levels.

### Q8.3 — What happens on a failing mark?

`LevelPlayerPage._markCanvasWork` (`level_player_page.dart:260-281`) shows a
"More practice" dialog and calls `LevelActivityViewModel.restart()`. That bumps an
`attempt` counter, which the canvas views watch:

```dart
if (_activity.attempt != _attempt) {
  _controller.clear();          // fresh page
  _captured.clear();            // and every captured letter, for tracing
}
```

Why an `attempt` counter and not just the item index? Because a drawing level can
be a **single card** — the index would not change, so the view could not tell
"restart" from "nothing happened" (`level_activity_viewmodel.dart:18-21`).

Also note: backing out of the marking screen without choosing pops `null`, and
the flow returns leaving the page exactly as it was. A parent can go away and
come back for a second look without the child's work being destroyed.

### Q8.4 — A canvas level with a quiz gets graded twice. How are the two combined?

Averaged, in `QuizViewModel.combineWithParentMark`
(`lib/viewmodels/quiz_viewmodel.dart:15-21`):

```dart
static int combineWithParentMark({required int quizPercent, int? parentMark}) {
  if (parentMark == null) return quizPercent;
  return ((parentMark + quizPercent) / 2).round();
}
```

The parent's mark rides along in `QuizArgs.parentMark` through the route
arguments. Rationale: the level has two halves — making something, and knowing
something about it — and neither should be able to erase the other. Replacing the
mark with the quiz score would mean a lucky round of multiple choice cancels a
poor tracing; ignoring the quiz would waste it. The quiz screen shows a
"Marked 70 %" chip so the parent can see the mark is still in play.

### Q8.5 — How is finished canvas work carried to the marking screen?

As `CanvasWork` (`lib/models/canvas_work.dart`) — `title`, `prompt`,
`canvasSize`, `List<DrawingStroke>`, and an optional `TraceGlyphLayout guide`.
**Geometry, not an image.** The comment states the payoff:

> strokes re-render at any size, which is what lets a full-screen canvas appear
> as a thumbnail beside two others without going near image encoding.

`CanvasWorkPreview` (`lib/widgets/drawing/canvas_work_preview.dart`) replays it by
laying the strokes out at their **original** canvas size inside a `FittedBox`, so
the ink and the dotted guide stay in perfect register at any scale. It also drops
the pale ghost letter (`showGhost: false`) — the parent is judging the child's
line, so only the dots and the outline stay behind it.

Because `canvasSize` travels with the strokes, the scorer can re-derive exactly
the geometry the child drew at, even though the marking screen is a different
size.

---

## 9. Audio module

### Q9.1 — How is audio designed? What is a "cue key"?

Content never stores a file path. It stores a **cue key** — a short logical name
like `english_letter_a`, `koala_math_intro`, `trace_letter_a` — on
`ContentItem.audioCueKey` and `KoalaGuideMessage.audioCueKey`.

`KoalaAudioCueSource.resolve`
(`lib/services/audio/koala_audio_player.dart:57-88`) turns a key into a playable
source with a small set of rules:

```
1. trim; empty/null            → no source (button hides entirely)
2. parses as http/https + host → REMOTE URL   (Firebase Storage / CDN)
3. otherwise                   → ASSET
     strip a leading "assets/"
     if it has no "/", prefix the caller's base path
     if it has no extension, append ".mp3"
```

So `english_letter_a` → `assets/audio/learning/english_letter_a.mp3`, and
`https://…/cue.mp3` plays straight from the network. The base path is supplied by
the caller — `audio/koala` by default, `audio/learning` from
`ContentAudioButton` (`activity_chrome.dart:11, 47`) — so the same resolver serves
both libraries without either knowing about the other.

### Q9.2 — Why indirection instead of just storing the asset path?

Four reasons:

1. **Content stays backend-agnostic.** The identical cue key can resolve to a
   bundled asset today and to a Firebase Storage URL tomorrow, with no content
   migration — admin-authored content simply supplies a full URL.
2. **Content is portable across platforms** — no `assets/` prefixes or file
   extensions baked into curriculum data.
3. **A missing recording is not a broken screen.** See Q9.3.
4. **It is testable without any audio hardware**, because resolution is a pure
   function. `test/koala_audio_player_test.dart` and
   `test/level_player_audio_test.dart` cover it.

### Q9.3 — What happens when the audio file does not exist?

A **three-tier graceful degradation chain**, which matters because the audio
folders are currently empty (see `MANUAL_SETUP.md` §6):

```
AudioplayersKoalaAudioPlayer.playCue
  ├─ resolve → null?              → didPlay:false, "No audio cue is available."
  ├─ try asset / URL playback     → success: didPlay:true, source recorded
  └─ on ANY error (catch Object)  → SystemKoalaAudioPlayer
                                      → SystemSound.play(click)
                                      → "Audio file unavailable; played fallback cue."
```

The button always responds, the flow is never blocked, and the returned
`KoalaAudioPlaybackResult` records *which* tier fired (`asset`, `remoteUrl`,
`systemCue`, `none`) plus the resolved path — so the behaviour is observable and
assertable in tests rather than a silent swallow.

`ContentAudioButton` renders nothing at all when there is no cue key, so a card
without audio shows no dead button.

### Q9.4 — Why an abstract `KoalaAudioPlayer` interface?

Because `audioplayers` needs platform channels, which do not exist in a widget
test. The interface has three implementations: the real
`AudioplayersKoalaAudioPlayer`, the `SystemKoalaAudioPlayer` fallback, and test
fakes. The real player also accepts optional `playAsset` / `playRemoteUrl`
callbacks purely so tests can intercept playback without mocking the plugin
(`koala_audio_player.dart:122-127`). Widgets look it up defensively with a
`try/catch` on `ProviderNotFoundException`, so a screen rendered outside the
provider tree degrades to no audio button instead of crashing.

### Q9.5 — Why `audioplayers` and not `just_audio` or TTS?

`audioplayers` supports the exact two source types needed (`AssetSource`,
`UrlSource`) with a one-line API and a single shared player instance created
lazily. `just_audio` is stronger at playlists, gapless playback and background
audio — none of which apply to 2-second cues.

Text-to-speech was rejected for the primary path because pronunciation quality
matters enormously when teaching phonics, and Urdu/Nastaliq TTS quality on
device is poor. Pre-recorded human audio is the pedagogically correct choice;
the cue-key indirection means TTS could be added later as another resolution tier
without touching content.

---

## 10. Parent vs child separation

### Q10.1 — How are parents and children handled separately?

This is a core design axis, so the answer has four parts: **identity**,
**navigation**, **the lock**, and **age adaptation**.

**Identity — only the parent is a security principal.**
A child is *not* an account. There is exactly one authenticated user
(`ParentAccount`, backed by Firebase Auth). Children are documents owned by that
user: `parents/{uid}/childProfiles/{childId}`. A child cannot sign in, cannot own
data, and cannot exist without a parent. That is a deliberate child-safety
posture: no child credentials to leak, no child-facing account recovery, and one
`request.auth.uid` to check in security rules.

The active child is held in `ActiveChildSession`
(`lib/viewmodels/active_child_session.dart`) — a `ChangeNotifier` with
`selectProfile` / `clear`. It is **session state, not auth state**: switching
profile is a `clear()` + navigate, and no screen that needs a child renders
without one (`HomePage` shows a "Choose a learner profile first" screen if
`activeChild == null`).

**Navigation — two route families.**

```
parent surface                    child surface
  /login /signup                    /child/select
  /onboarding/*                     /child/home
  /parent/dashboard                 /child/module/levels
  /profiles/edit                    /child/level/player
  /parent/reports                   /child/quiz
  /parent/reminders                 /child/celebration
  /parent/leaderboard               /child/video, /child/video/player
  /parent/marking
  /admin, /admin/content
  ────────── /parental-lock ──────────
```

The child surface is the default one. `AuthFlowRouter.routeAfterAuth` sends a
parent who has finished onboarding to `/child/select` — faces and names only —
and only to `/profiles/edit` first when the account has no child yet. The
parent dashboard is never on that path: it is reached on purpose, through the
labelled parent-area button in the `ChildActionBar` that the child selection
screen and `HomePage` both carry along their bottom edge, and that button goes
through `/parental-lock`.

`/child/select` stays at the bottom of the child surface's stack: opening a
child pushes `/child/home` rather than replacing, and the two jumps that do
clear the stack (saving a profile, "Home" on the celebration screen) stop
unwinding at `/child/select` instead of wiping it. So back always leads
outward to the faces, never sideways into the parent dashboard.

**The lock — the crossing point.**

**Age adaptation** — see Q10.4.

### Q10.2 — Explain the parental lock. Why a maths challenge?

`ParentalLockRepository.createChallenge` generates a small addition problem
(`left ∈ 2..7`, `right ∈ 1..5`) and the view model verifies the typed answer
(`lib/repositories/parental_lock_repository.dart`,
`lib/viewmodels/parental_lock_viewmodel.dart`).

Why a maths challenge rather than a PIN or a password:

- **It requires no setup and cannot be forgotten.** A PIN needs a create-PIN flow,
  a reset flow, and secure storage; a forgotten PIN locks a parent out of their
  own child's data.
- **It is age-appropriate gating, not authentication.** Real authentication has
  already happened — the parent is signed in with Firebase Auth. This gate only
  answers "is an adult holding the device *right now*", which is a different and
  much weaker question. The threat model is a 3-year-old, not an attacker.
- Sums up to 12 are beyond a 2–4-year-old and trivial for an adult, which is
  exactly the discrimination required.

Abuse resistance is still present: **3 wrong answers → a 30-second lockout**,
with a `Timer` that clears the message when it expires, and **a fresh challenge is
generated after every failure** so repeated guessing cannot brute-force one
constant (`parental_lock_viewmodel.dart:56-74`).

*Worth volunteering:* the generator used to carry a **fixed seed**
(`Random(7)`), so every install opened on the very same sum. Against the actual
threat model — a pre-schooler who cannot do addition at all — that was
irrelevant, but against a memorising 8-year-old sibling it was a real weakness:
the gate could be passed from memory without doing the arithmetic. The seed now
comes from the platform, with an optional `seed:` argument left in for the one
test that needs a challenge it can predict
(`parental_lock_repository.dart:21-38`).

### Q10.3 — How is the lock reused? Show the two shapes.

`ParentalLockArgs` supports both patterns, which is why the route is built as
`MaterialPageRoute<bool>`:

```dart
// 1. Hand-off: solve the sum, land on the destination.
Navigator.pushNamed(parentalLock, arguments: const ParentalLockArgs(
  successRoute: RouteNames.profileEdit,
  successArguments: ProfileEditArgs(),
));

// 2. Verification: pop `true` and let the caller continue.
final unlocked = await navigator.pushNamed<bool>(
  parentalLock, arguments: const ParentalLockArgs());
if (unlocked != true) return;
await navigator.pushNamed<ParentMark>(parentMarking, ...);
```

Shape 1 is used for the four parent-dashboard entries (create profile, edit
profile, reports, admin dashboard — `profile_selection_page.dart:163-198`).
Shape 2 is used by the level player before marking, because it has more work to
do afterwards (`level_player_page.dart:245-258`). Documented at
`app_router.dart:96-99`.

Everything behind the lock: profile creation/editing, parent reports, the admin
dashboard, and canvas marking.

### Q10.4 — How does the experience adapt to the child's age?

| Mechanism | Where |
| --- | --- |
| Age → stage (2–4) | `AgeStageHelper.stageForAge` |
| Modules filtered by stage | `CachedContentRepository.getModulesForStage` → `module.supportsStage(stage)` |
| Levels filtered by stage, with graceful fallback | `_levelsForStage` — exact stage; else the highest lower stage; else everything |
| **Quizzes only from age 3** | `AgeStageHelper.shouldShowQuiz(age) => age >= 3`, checked in `LevelPlayerPage._complete` |
| Tracing hidden below stage 2 | `minStage: 2` on the module |
| Leaderboard grouped by stage | `leaderboards/stage-{stage}/entries/{childId}` |

The `_levelsForStage` fallback is worth calling out: if a module has no levels for
the child's exact stage, it serves the closest *lower* stage rather than an empty
screen. A 4-year-old opening a module authored only up to stage 3 sees stage 3
content, not a blank list.

### Q10.5 — How is a child prevented from reaching parent data?

Four independent layers:

1. **Navigation** — the child surface is where a signed-in parent lands, and
   the only door out of it is the parent-area button, which opens the lock
   rather than the dashboard. Parent routes stay reachable only from the
   dashboard behind it.
2. **The parental lock** on every sensitive parent route.
3. **Session scoping** — child screens read `ActiveChildSession`, which holds
   exactly one profile; there is no API on it to enumerate siblings.
4. **Server-side rules** — even a tampered client cannot read another parent's
   data: `firestore.rules` scopes every parent document to
   `request.auth.uid == parentId`, and child progress to `ownsChildProfile()`.

Layers 1–3 are usability; layer 4 is the actual security boundary. That
distinction is worth stating explicitly to a panel.

### Q10.6 — Why is `maxProfilesPerParent = 3` enforced in the repository rather than the UI?

Because a rule enforced in a form is a suggestion. `createProfile` reads the
existing profiles and throws `ProfileLimitException`
(`child_profile_repository.dart:59-61`) before any write. The UI catches it and
shows the message. Same reasoning for `ProfileNotFoundException` on update and
delete, both of which also verify `profile.parentId == parentId` — an ownership
check on the client, mirrored by the ownership check in the Firestore rules.

---

## 11. Auth, onboarding & admin

### Q11.1 — Describe the parent authentication flow.

`FirebaseAuthRepository` (`lib/repositories/firebase_auth_repository.dart`)
composes two data sources: `FirebaseAuthService` (credentials) and
`ParentFirestoreService` (the parent document). Every entry point —
`signIn`, `signUp`, `currentParent` — funnels through
`ensureParentDocument(parent)`, so the Firestore profile is guaranteed to exist
and to carry a role before any screen reads it. There is no code path that
produces an authenticated user without a parent document.

New documents default to `role: 'parent'`, and the Firestore rules enforce that
on create (`request.resource.data.role == 'parent'`).

### Q11.2 — Why is there an onboarding gate before a parent can use the app?

`AuthFlowRouter.routeAfterAuth` (`lib/core/routing/auth_flow_router.dart`) is the
single place that decides where a signed-in parent lands:

```dart
final route = !onboarding.manualCompleted ? onboardingManual
            : !onboarding.testPassed      ? onboardingLanguage
                                          : profiles;
```

Manual → language → readiness test → profiles. The gate exists because the app's
pedagogy depends on the adult: canvas work is parent-marked, screen time is
parent-paced, and the guidance is written for a parent sitting alongside. The
readiness test (70 % to pass, `OnboardingViewModel.passingScore`) confirms they
have read it.

Note the subtlety at `auth_flow_router.dart:22-24`: an unfinished test routes to
the **language picker**, not the test, so a returning parent still gets to choose
the language the test is written in.

### Q11.3 — How does the English/Urdu onboarding language switch work without losing answers?

`OnboardingViewModel.setLanguage` reloads the manual pages and readiness
questions in the new language but **does not clear `_selectedAnswers`**, because
both language variants use the same question ids and the same option order
(`onboarding_viewmodel.dart:47-58`). A parent switching half way through does not
start over, and no answer silently flips from right to wrong.

### Q11.4 — How is admin access controlled?

Three layers, deliberately redundant:

1. **Role on the account.** `ParentAccount.canManageAdminContent` derives from
   `parents/{uid}.role == 'admin'`. In local demo mode,
   `admin@littlelearners.local` is treated as admin after signup.
2. **A repository decorator.** `AuthorizedAdminContentRepository` and
   `AuthorizedAdminKoalaGuideRepository` wrap the real repositories and call
   `requireContentAdmin()` — which throws `AdminPermissionException` — before
   **every** method (`admin_authorization_repository.dart:97-100`). This is
   written once and cannot be forgotten on a new method, unlike an `if` in each
   handler. `AuthorizedMediaAssetRepository` does the same for uploads.
3. **Firestore rules.** `isAdmin()` re-reads the role server-side for
   `learningModules`, `learningLevels`, `koalaGuideMessages` and `mediaAssets`.

Plus a privilege-escalation guard: `keepsRoleUnchanged()` blocks a parent from
writing their own `role` field on update, and `allow delete: if false` on parent
documents. Promotion has to come from a trusted console.

### Q11.5 — What is the content publishing workflow?

`AdminPublishStatus` (draft / review / published) plus `version`, `submittedAt`
and `publishedAt` on both `AdminContentModule` and `AdminContentLevel`. Child
devices only ever pull *published* content —
`ContentRemoteDataSource.getPublishedContent()` — and the rules enforce the same
boundary server-side (`resource.data.isPublished == true || isAdmin()`). So a
half-written level cannot reach a child, whatever the client does.

---

## 12. Leaderboard & privacy

### Q12.1 — A leaderboard for toddlers sounds risky. How is it made safe?

It is aimed at parents, and it is defended on three axes
(`lib/repositories/leaderboard_repository.dart`):

1. **Opt-in, and revocable.** `ChildProfile.leaderboardOptIn` defaults off. If it
   is off, `refreshEntry` does not merely skip the upload — it **deletes** any
   existing entry (`leaderboard_repository.dart:49-52`). Turning the setting off
   retroactively removes the child from the board.
2. **Anonymisation is a per-profile choice.** `_displayNameFor` returns either the
   first name only (`displayPreference == 'firstName'`) or a generated
   `Learner 8f2c` handle derived from the last 4 characters of the child id. No
   full names, ever.
3. **Age-stage segregation.** Entries live in `leaderboards/stage-{stage}/entries`
   and are only ever queried within a stage, so a 4-year-old never out-ranks a
   2-year-old.

Deleting a child profile calls `LeaderboardSyncService.removeChild`, so the
remote entry goes with it.

### Q12.2 — How is the leaderboard score computed, and why not just use quiz scores?

```dart
per level: (completed ? 100 : 0) + (score ?? 0) + (stars × 10) + (rewardEarned ? 25 : 0)
```

Summed across all levels. Completion is weighted heaviest deliberately: the
behaviour worth rewarding at this age is **finishing things and coming back**, not
scoring highly. A child who completes ten levels at 60 % outranks one who
completes three at 100 %. Ties break on stars, then on most recent activity —
so an active learner edges out a dormant one.

### Q12.3 — What happens if publishing the score fails?

The board still loads. `LeaderboardViewModel.loadLeaderboard`
(`lib/viewmodels/leaderboard_viewmodel.dart:36-44`) wraps the publish step in its
own `try/catch` with an explicit comment:

> Publishing this parent's own scores is best effort. If it fails the board is
> merely a little stale, which is no reason to show nothing.

Only the *read* sets `_errorMessage`. This was a real bug — a rules failure on
the write used to blank the whole screen — and is now covered by
`test/leaderboard_resilience_test.dart`.

---

## 13. Localisation, RTL & Urdu

### Q13.1 — How is Urdu supported?

Two bundled fonts (`pubspec.yaml`): **Fredoka** for Latin, **Noto Nastaliq Urdu**
for Urdu. `LearningTextDirection`
(`lib/core/utils/learning_text_direction.dart`) centralises every direction and
font decision:

- `forModule` — module category `urdu` → RTL.
- `forText` — regex `[؀-ۿ]` (the Arabic Unicode block) → RTL.
- `forLevel` — module id `urdu` → RTL, **else sniff the level's own title and
  subtitle.** The comment explains why: *Urdu content is not confined to the Urdu
  module — the tracing module teaches Urdu letters too.*
- `styleFor` / `styleForText` — attach the Nastaliq family only when the text is
  RTL, otherwise return the base style untouched.

Views then wrap individual strings in `Directionality` and pick
`CrossAxisAlignment.end` for RTL, so an Urdu card mirrors correctly inside an
otherwise LTR screen. The tracing module gets this for free:
`TraceGlyph.resolve` asks `LearningTextDirection` for the direction and font, so
an Urdu glyph is laid out and scored by exactly the same code as an English one
(covered by "an Urdu glyph resolves right-to-left with the Nastaliq font" in
`test/trace_scorer_test.dart`).

### Q13.2 — Why per-string detection instead of `flutter_localizations` and ARB files?

Because the two problems are different. This app does **not** translate its UI —
it *presents bilingual learning content* inside an English shell. An Urdu word can
appear on a card in the English module, and an English hint can sit under an Urdu
glyph. A locale-based system localises the whole app at once, which is the wrong
granularity: it cannot decide the direction of a single card.

Onboarding, which *is* genuinely translated, uses a simple explicit approach —
`OnboardingLanguage` plus parallel content in
`lib/core/localization/onboarding_strings.dart` and
`lib/data/onboarding_content.dart`, keyed by identical question ids so answers
survive a switch.

The honest limitation: full app-wide localisation would need
`flutter_localizations` + ARB. The current design covers the actual requirement
(bilingual *content*) without that machinery.

---

## 14. Reminders & notifications

### Q14.1 — How do learning reminders work?

`LearningReminder` (`lib/models/learning_reminder.dart`) holds an hour, a minute,
a set of weekdays, an enabled flag, and `lastTriggeredAt`. Two pure methods carry
the logic:

- `isDueAt(DateTime)` — enabled, weekday matches, hour/minute match, **and not
  already triggered on the same calendar day.** That last clause is the
  idempotency guard that stops a reminder firing repeatedly within its minute.
- `nextOccurrenceAfter(DateTime)` — walks up to 7 days forward for the next
  matching weekday, preserving UTC-ness.

`ReminderNotificationDeliveryRepository.deliverDueReminders` asks for due
reminders, creates a `NotificationDelivery` record for each, and calls
`markTriggered` (`notification_delivery_repository.dart:49-81`). Delivery ids are
sanitised to Firestore-safe characters.

### Q14.2 — Why is there a delivery record rather than a real push notification?

Because the delivery *pipeline* is the part that has to be right, and it is
complete: due-detection, idempotency, a persisted delivery with
`scheduled/delivered/read` status, and read tracking. What is not wired is the
transport — FCM plus `flutter_local_notifications` for the OS-level banner.

That is a deliberate slice, and it is the honest answer to give: the domain logic
is done and unit-tested (`test/learning_reminder_test.dart`,
`test/notification_delivery_repository_test.dart`) with no dependency on a device
or a push certificate; adding FCM is an adapter behind
`NotificationDeliveryRemoteDataSource`, not a redesign.

---

## 15. Koala Guide (guidance engine)

### Q15.1 — What is the Koala Guide and how does it choose what to say?

An in-app mascot that surfaces contextual guidance. A `KoalaGuideMessage`
declares a `trigger` (one of 14 — `dashboardWelcome`, `activityStart`,
`quizRetry`, `lockedLevel`, `parentReport`, …), an `audience` (child or parent),
optional `moduleId`, `levelId`, `minStage`/`maxStage`, a `mood`, an optional
`audioCueKey`, an optional `parentTip`, and a `priority`.

Selection is a **filter-then-rank** over the message pool
(`lib/repositories/koala_guide_repository.dart:25-51`):

1. `matches(request)` — trigger and audience must match exactly; any declared
   module/level/stage constraint must be satisfied.
2. `specificityFor(request)` — a score: `+100` level match, `+60` module match,
   `+20` stage-bounded, `+5` has audio, `+3` has a parent tip, plus the author's
   `priority`. Ties break on id, so selection is **deterministic** — the same
   context always yields the same message, which is what makes it testable.
3. If nothing matches, a synthesised fallback message is returned, using the
   caller's `fallbackMessage`.

Admin-synced messages are searched *before* seed messages
(`[..._syncedMessages, ..._seedMessages]`), so published content overrides the
bundle without deleting it.

### Q15.2 — Why a rules engine instead of hardcoding a string per screen?

Because the same 14 triggers appear on ~20 screens, and guidance needs to vary by
module, level and age without touching those screens. `ContextualKoalaGuide` is a
declarative widget:

```dart
ContextualKoalaGuide(
  trigger: KoalaGuideTrigger.activityStart,
  audience: KoalaGuideAudience.child,
  moduleId: level.moduleId, levelId: level.id, stage: level.stage,
  fallbackMessage: level.subtitle,
)
```

An admin can add a message targeted at exactly one level, and it takes precedence
automatically because its specificity score is higher — no code change, no
deployment. And the widget degrades safely: if the repository is not in the tree
(a widget test, say) it catches `ProviderNotFoundException` and renders the
fallback text (`koala_guide.dart:263-269`).

---

## 16. Testing strategy

### Q16.1 — What is tested, and how?

**204 tests across 56 files, all passing** (`flutter test`), ~6,100 lines. There
is roughly one test file per production concern:

| Layer | Examples |
| --- | --- |
| Algorithms | `trace_scorer_test`, `drawing_canvas_controller_test`, `age_stage_helper_test`, `validators_test` |
| View models | `learning_viewmodel_test`, `quiz_viewmodel_test`, `parental_lock_viewmodel_test`, `leaderboard_viewmodel_test`, `onboarding_viewmodel_test`, `profile_viewmodel_test`, … |
| Repositories | `progress_repository_test`, `content_repository_test`, `child_profile_repository_test`, `admin_content_repository_test`, `admin_authorization_repository_test`, … |
| Persistence | `content_dao_test`, `child_profile_dao_test`, `sync_outbox_dao_test`, and a mapper test per entity |
| Sync | `sync_service_test`, `progress_sync_service_test`, `content_sync_service_test`, `sync_orchestrator_test`, `koala_guide_sync_service_test` |
| Widgets | `canvas_level_view_test`, `parent_marking_test`, `auth_pages_widget_test`, `onboarding_pages_widget_test`, `leaderboard_page_widget_test`, `video_learning_page_widget_test`, `koala_guide_widget_test`, `module_card_widget_test` |
| Content integrity | `content_revision_test` — asserts properties of the real bundled curriculum |
| Resilience | `leaderboard_resilience_test` — the board still loads when publishing fails |

### Q16.2 — Give an example of a test that proves a design decision rather than a line of code.

Several, by design. Tests are written as behavioural claims:

- *"only 'needs practice' fails, on every canvas level in the app"* — iterates the
  real seed content and asserts the `ParentMark` scale is coherent with every
  authored `passingScore`. If someone adds a drawing level with `passingScore:
  40`, this fails.
- *"the promised stars match the progress rules"* — asserts `ParentMark.stars`
  agrees with `CachedProgressRepository._starsFor`, so the two cannot drift.
- *"drawing away from the letter scores badly"* and *"a small overshoot past the
  letter is forgiven"* — pin the scorer's calibration, not its implementation.
- *"reinstalling the bundle keeps levels the parent downloaded"* — protects the
  content-revision migration.
- *"an eraser stroke removes ink before grading"* — proves the mask rasteriser
  and the live canvas share semantics.

### Q16.3 — How can you test the tracing scorer without a device?

Because `TraceScorer` depends only on `dart:ui` offscreen rendering, which
`flutter_test` provides. A test constructs a `TraceGlyphLayout`, synthesises
`DrawingStroke`s (e.g. strokes that follow the ink rect, or strokes deliberately
placed away from it), and asserts on the resulting score band. No golden images,
no camera, no device.

### Q16.4 — Why no integration/E2E tests?

Honest answer: the pyramid is deliberately weighted to fast unit and widget tests
because they run in ~90 seconds and gate every change. The gap is a
`integration_test` suite driving a real device through
signup → onboarding → profile → level → marking → celebration. The architecture
supports it — `USE_FIREBASE=false` gives a fully functional app with in-memory
repositories, which is exactly the seam an E2E harness would use.

---

## 17. Security

### Q17.1 — Summarise the security model.

| Boundary | Mechanism |
| --- | --- |
| Who is the user | Firebase Auth; only parents have accounts |
| Parent data isolation | `isOwnParent(parentId)` on `parents/{parentId}` and all subcollections |
| Child progress isolation | `ownsChildProfile(childId)` — an `exists()` check against the caller's own `childProfiles` |
| Privilege escalation | `keepsRoleUnchanged()` on parent update; `role == 'parent'` forced on create; `allow delete: if false` |
| Admin writes | `isAdmin()` reads `parents/{uid}.role` server-side |
| Unpublished content | Readable only by admins: `resource.data.isPublished == true \|\| isAdmin()` |
| Leaderboard writes | Must own the child **and** `request.resource.data.parentId == request.auth.uid` |
| Client-side defence in depth | `Authorized*Repository` decorators, ownership checks in repositories, the parental lock |

### Q17.2 — Point at a security bug you found and fixed.

The leaderboard delete rule. It originally read `resource.data.parentId` with no
guard, but **`resource` is null when the document does not exist** — so deleting
a non-existent entry made the rule error out and deny the request, which failed
*every* leaderboard refresh (opt-out deletes a possibly-absent doc on every
sync). The fix is documented in the rules file itself:

```
allow delete: if ownsChildProfile(childId)
  && (resource == null || resource.data.parentId == request.auth.uid);
```

The Dart side was hardened at the same time so a publish failure no longer blanks
the screen (Q12.3). This is a good example to volunteer: it shows the rules were
actually exercised, not just written.

### Q17.3 — Any secrets in the repository?

`android/app/google-services.json` is present, which is normal — it contains
public client identifiers, not credentials; Firebase's security model puts the
enforcement in Auth and rules, both of which are in place. There are no API keys,
service-account files or private keys in the source. iOS is **not** configured
(no `GoogleService-Info.plist`) and that is documented in `MANUAL_SETUP.md` §5
rather than left as a surprise.

---

## 18. Known limitations & future work

State these before the panel finds them — it reads as engineering judgement
rather than an oversight. Each is a documented, bounded gap, not a design flaw.

| # | Limitation | Why it is bounded | Fix |
| --- | --- | --- | --- |
| 1 | **Audio folders are empty.** Every cue key points at a file that was never recorded. | The player falls back to a system sound and never breaks a flow; resolution is fully tested. Documented in `MANUAL_SETUP.md` §6. | Drop `<cueKey>.mp3` files into `assets/audio/{koala,learning}/`. No code change. |
| 2 | **Connectivity detection is stubbed** (`AlwaysOnlineConnectivityStatusProvider`). | The `ConnectivityStatusProvider` seam exists and is exercised by `sync_orchestrator_test`; failures still fall back to per-task backoff. | Implement the interface over `connectivity_plus`; one class, one wiring line. |
| 3 | **Notifications are records, not OS banners.** | The whole due/idempotency/delivery/read pipeline is done and tested. | Add FCM + `flutter_local_notifications` behind the existing data source. |
| 4 | **Video URLs point at a Flutter sample clip**; no offline video caching. | Deliberate placeholder, documented in `MANUAL_SETUP.md` §7 with the reminder to bump `bundledContentRevision`. | Replace URLs; add a caching player. |
| 5 | **No integration/E2E suite.** | 204 unit/widget tests, and `USE_FIREBASE=false` gives a fully driveable app. | Add `integration_test` over the in-memory build. |
| 6 | **Conflict resolution uses device clocks.** | LWW with an unsynced-local bias; deletes go through the outbox, which is the case naive LWW gets wrong. | `syncedAt` server timestamps are already written; switch ordering to them. |
| 7 | **iOS Firebase not configured.** | Android is complete; documented in `MANUAL_SETUP.md` §5. | `flutterfire configure` or add `GoogleService-Info.plist`. |
| 8 | **Firestore rules are written but must be deployed.** | Both `firestore.rules` and `storage.rules` are in the repo. | `firebase deploy --only firestore:rules,storage` — blocked on a broken local CLI, documented in §4. |
| 9 | **`ChangeNotifier` broadcasts coarse updates.** | Mitigated by keeping view models small and single-purpose. | `Selector`/`context.select` at the hot spots if profiling shows it matters. |
| 10 | **Bundled content needs a manual revision bump.** | The mechanism exists, is tested, and the requirement is documented in three places including a bold line in `MANUAL_SETUP.md`. | A build-time hash of `seed_content.dart` would remove the human step. |
| 11 | **Parental-lock challenges use a fixed RNG seed** (`Random(7)`). | Irrelevant against a 2–4-year-old, and it keeps the lock deterministic under test. | `Random()` in production; inject the seed for tests. |

---

## 19. Rapid-fire answers

**Q: Why Flutter?** One codebase for Android and iOS; the drawing and tracing
modules depend on direct `Canvas`/`CustomPainter` access and offscreen
rasterisation, which Flutter exposes natively — in React Native the same work
would need a native module or a WebView.

**Q: Why SQLite and not Hive/Isar/shared_preferences?** The data is relational —
progress is keyed `(childId, levelId)`, content is modules → levels → items, and
queries filter by module/stage and by `isSynced`. That is a relational workload
with indexes, not a key-value one. `sqflite` is also the most portable and
best-understood option for handover.

**Q: Why is the DB version 5 already?** Because migrations were written as
features landed (outbox → content → progress → meta) rather than by wiping the
database. `onUpgrade` applies them cumulatively, so an early install upgrades
intact.

**Q: What is `app_meta` for?** A tiny key-value table for bookkeeping that is not
domain data. Currently one key: which revision of the bundled content is
installed.

**Q: Why are mappers separate from DAOs?** `content_mapper`, `progress_mapper`,
`child_profile_mapper`, `sync_outbox_mapper` isolate row↔model translation, so it
is unit-testable without a database — there is a test file for each.

**Q: Why does `Firestore.instance.settings` enable persistence?**
`main.dart:12-14`. It gives a second offline layer beneath the app's own SQLite
cache, so even the remote reads survive a dropped connection.

**Q: Why `switch` expressions everywhere?** Dart 3 exhaustiveness. Adding a value
to `LevelType`, `DrawingTool` or `ParentMark` makes every unhandled `switch` a
**compile error** rather than a silent fallthrough — the compiler enforces that
new content types are handled everywhere.

**Q: What is `revision` on the canvas controller for?** An O(1) repaint check.
See Q6.7.

**Q: Why does `CanvasWork` store `canvasSize`?** So strokes and the guide can be
replayed and re-scored in the coordinate system they were drawn in, at any
display size. See Q8.5.

**Q: Why `Listener` and not `GestureDetector` on the canvas?** Pointer ids and
pressure. See Q6.1.

**Q: What stops a palm from drawing?** `_activePointer` — the canvas ignores any
pointer while another is active (`drawing_canvas.dart:74-76`).

**Q: How would you add a ninth learning module?** Add a `LearningModule` and its
levels to `seed_content.dart`, add a `ModuleCategory` value and its colour/icon in
`ModuleVisuals`, bump `bundledContentRevision`. If it needs a new interaction, add
a `LevelType` value — and the compiler will list every `switch` that must handle
it.

**Q: How would you swap Firebase for another backend?** Implement the
`services/remote/*` interfaces against the new backend and change the ternaries in
`app.dart`. Repositories, view models and views are untouched, because none of
them import `cloud_firestore`.

**Q: What is the single thing you are most proud of?** The tracing scorer:
a glyph-agnostic, stroke-order-agnostic, dependency-free grading algorithm that
reuses the live canvas renderer so the child is measured on exactly what they saw
— and that is then deliberately demoted to *advice*, because the design decided a
parent's judgement outranks a pixel count.
