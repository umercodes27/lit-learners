# Manual setup required

Things that cannot be fixed from the Dart code alone. Each item lists the
symptom you see in the app, the cause, and what to do about it.

Ordered roughly by how much they hurt.

---

## 0a. Google sign-in needs enabling and fingerprints

**Symptom** — "Continue with Google" opens the chooser and then fails, or the
app reports *Google sign-in is not configured yet*, or *Google did not return
an ID token*.

**Cause** — the Google provider has never been switched on for
`little-learner-9d2f1`, and the Android app has no OAuth clients. You can see
this directly in `android/app/google-services.json`: `"oauth_client": []`. That
array is empty because no SHA-1/SHA-256 fingerprint has been registered, and it
is what the Gradle plugin turns into the `default_web_client_id` resource the
plugin needs for an ID token.

**Fix**

1. Firebase console → **Authentication → Sign-in method → Google → Enable**.
   Set a project support email and save.
2. Get the debug fingerprints:

   ```bash
   cd android && ./gradlew signingReport
   ```

   Copy the **SHA1** and **SHA-256** from the `debug` variant. Do the same for
   your release keystore before shipping.
3. Firebase console → **Project settings → Your apps → Android app
   (`com.example.little_learners`) → Add fingerprint**. Add both.
4. **Re-download `google-services.json`** and replace
   `android/app/google-services.json`. Confirm `oauth_client` is no longer
   empty and contains an entry with `"client_type": 3` — that is the Web client
   id the Android plugin uses.
5. `flutter clean && flutter run`.

If the generated resource is missing or wrong, you can pass the Web client id
explicitly instead:

```bash
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>.apps.googleusercontent.com
```

**iOS** additionally needs, once `GoogleService-Info.plist` exists (see item 5):

* the `REVERSED_CLIENT_ID` value from that plist added to `ios/Runner/Info.plist`
  as a URL scheme:

  ```xml
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLSchemes</key>
      <array><string>com.googleusercontent.apps.XXXXXXXX-YYYYYYYY</string></array>
    </dict>
  </array>
  ```

* or `--dart-define=GOOGLE_IOS_CLIENT_ID=<ios client id>` if you prefer to keep
  it out of the plist.

**Web** needs no fingerprints, but it does need two things passed in, because a
browser build has no `google-services.json` or plist to read:

1. Firebase console → **Project settings → Your apps → Add app → Web**. Register
   one if there is not one already; this is also where the Firebase web config
   in item 0c comes from.
2. Google Cloud console → **APIs & Services → Credentials → the Web client** →
   add your dev origin (`http://localhost:<port>`) to **Authorised JavaScript
   origins**. Flutter picks a random port unless told otherwise, so pin it:

   ```bash
   flutter run -d chrome --web-port=5000 \
     --dart-define=GOOGLE_WEB_CLIENT_ID=<web client id>.apps.googleusercontent.com \
     --dart-define=FIREBASE_API_KEY=... # and the rest of item 0c
   ```

Without `GOOGLE_WEB_CLIENT_ID` the chooser never opens in a browser: there is
nothing for the plugin to identify the app with. Without the Firebase config,
Google sign-in is not reached at all — the app runs on local data, and the
button says so rather than signing anyone in.

Note the package name is still `com.example.little_learners`. Fingerprints are
registered per package name, so change it *before* doing this, not after.

### What it looks like when this is not done

The app does not fail; it falls back. `main.dart` treats a failed
`Firebase.initializeApp` as non-fatal, `app.dart` checks `Firebase.apps` and
uses the in-memory repositories instead, and every auth screen then shows the
*Not connected to Firebase* banner. In that state "Continue with Google"
refuses with a message pointing here, rather than signing in — it used to mint
a `google.parent@littlelearners.local` account and report success, which looked
exactly like a broken Google integration: no chooser, a different parent id on
every run, and the children created under the previous one gone.

---

## 0b. Password reset emails need the template configured

**Symptom** — "Send reset link" reports success but no email arrives.

**Cause** — the app calls `FirebaseAuth.sendPasswordResetEmail`, so Firebase
owns the whole flow: it composes the mail, hosts the page the link opens, and
writes the new password. Nothing about that is in this repo. When the mail does
not turn up it is almost always one of: the template was never reviewed, the
sender domain is unverified, or the mail landed in spam.

**Fix**

1. Firebase console → **Authentication → Templates → Password reset**. Open it
   once and save, even unchanged — this is also where you set the sender name,
   the reply-to address and the language.
2. Check the **From** address. The default `noreply@<project>.firebaseapp.com`
   works but is a common spam-filter casualty. To send from your own domain,
   use **Customise domain** and complete the DNS records it asks for.
3. Firebase console → **Authentication → Settings → Authorised domains**. The
   domain in the action link must be listed, or the link opens on an error page.
4. Test with a real inbox and **check the spam folder** before concluding it is
   broken.

**Rate limits** — Firebase throttles reset mail per address and per project.
Repeated taps during testing will start failing with `too-many-requests`; that
is the quota, not a bug.

**Note on account enumeration** — the app reports "No account found for this
email" when the address has no account, because `sendPasswordResetEmail` throws
`user-not-found`. That is friendly but it does tell an attacker which addresses
are registered. If you would rather not leak that, turn on **Email enumeration
protection** in Authentication → Settings, and change the app to show the same
confirmation either way.

---

## 0c. Notifications need permission on the device

**Symptom** — reminders are listed in the app but the phone never buzzes.

**Cause** — nothing in the console; this is a device-level permission. Android
13+ and every iOS version require the parent to say yes.

**Fix** — this is handled in the app: the reminders screen and the notification
centre both show a banner with an **Allow notifications** button, and send a
test notification once granted. Nothing to do in the Firebase console.

Worth knowing:

* Reminders are scheduled **locally on the device**, so they fire with the app
  closed and without any server. They are rescheduled after a reboot via the
  `RECEIVE_BOOT_COMPLETED` receiver in `AndroidManifest.xml`.
* They are scheduled **inexactly** on purpose. Android 14 only grants
  `SCHEDULE_EXACT_ALARM` to alarm-clock and calendar apps, so a learning nudge
  may land a few minutes late rather than to the second.
* If a parent revokes permission in system settings, the app notices next time
  the reminders screen opens and shows the banner again.
* There is **no push (FCM)** in this app — see item 0d.

---

## 0d. Firebase Cloud Messaging is not set up (and is not used yet)

**Symptom** — none, yet. This item exists so nobody assumes push works.

**Cause** — the app has no `firebase_messaging` dependency and no device
tokens. Every notification it shows is **scheduled locally on the phone** by
`flutter_local_notifications`. That is deliberate and it covers reminders
properly, but it means:

* Nothing can be sent to a parent **from your server or the Firebase console**.
  There is no "send a message to all parents" button that will reach anyone.
* A reminder only exists on the phone that created it. Sign in on a second
  device and that device schedules nothing until the parent opens the reminders
  screen there.
* Any content you add later — a new module, a weekly progress digest, an
  "your child has not played in five days" nudge — cannot be announced.

**If you decide you want push**, this is what it takes. It is not a small
change; treat it as its own piece of work.

*Console / manual side*

1. Firebase console → **Project settings → Cloud Messaging**. FCM is on by
   default for new projects; confirm the **Firebase Cloud Messaging API (V1)**
   is enabled.
2. **iOS only:** create an **APNs authentication key** (`.p8`) in the Apple
   Developer portal → Keys, with *Apple Push Notifications service* enabled.
   Upload it under **Cloud Messaging → Apple app configuration**, along with
   the Key ID and your Team ID. Push does **not** work on iOS without this, and
   it does not work in the simulator at all — you need a real device.
3. **iOS only:** in Xcode → Runner target → **Signing & Capabilities**, add
   **Push Notifications** and add **Background Modes** with *Remote
   notifications* ticked.
4. Both platforms need item 0a's config files in place first
   (`google-services.json`, `GoogleService-Info.plist`).

*Code side, roughly*

1. Add `firebase_messaging` to `pubspec.yaml`.
2. Store each device's token against the parent, e.g.
   `parents/{uid}/devices/{token}`, and refresh it on
   `onTokenRefresh`. Delete the token on sign-out, or the next person to use
   that phone gets the previous parent's notifications.
3. Reuse the existing plumbing rather than adding a parallel one: a foreground
   message should call `LocalNotificationService.showNow` so it looks like
   every other notification, and write a `NotificationDelivery` record so it
   lands in the notification centre with the rest.
4. Add a background handler annotated `@pragma('vm:entry-point')`, and register
   `ScheduledNotificationBootReceiver`'s sibling for FCM in the manifest.
5. Send from a scheduled Cloud Function using
   `getMessaging().sendEachForMulticast`. There is no `functions/` project in
   this repo yet, so that would be set up from scratch with `firebase init
   functions`.

Note that FCM would **replace nothing**: local scheduling stays the better
choice for reminders, because it works offline and needs no server. Push is for
things only the server knows about.

---

## 1. Avatar photo upload fails

**Symptom** — picking a photo on the child profile page shows
`Avatar upload failed: No object exists at the desired reference`.

**Cause** — `No object exists at the desired reference` is Firebase Storage's
`object-not-found`. The upload path (`profileAvatars/{parentId}/...`) and the
rules in `storage.rules` are both correct, and `parentId` really is the Firebase
Auth UID, so the reference is right. What is missing is the bucket itself:
**Storage has most likely never been enabled** for the project
`little-learner-9d2f1`. Enabling Auth and Firestore does not enable Storage.

**Fix**

1. Firebase console → **Build → Storage → Get started**. Accept the default
   bucket and pick a location. This is the step that actually creates
   `little-learner-9d2f1.firebasestorage.app`.
2. Deploy the storage rules (see item 3).
3. Retry the upload.

**If it still fails**, check that the bucket name in
`android/app/google-services.json` (`storage_bucket`) matches what the console
shows under Storage. A project created before the `.firebasestorage.app` naming
change may expect `little-learner-9d2f1.appspot.com` instead; if so, re-download
`google-services.json` from the console.

The app no longer blocks on this: a failed upload now offers to save the profile
with a colour avatar instead of silently discarding everything you typed.

---

## 2. Leaderboard rules need deploying

**Symptom** — the leaderboard screen said *Leaderboard could not load.*

**Cause** — the delete rule read `resource.data.parentId` without checking that
`resource` exists. Deleting a document that is not there made the rule error out
and deny the request, which failed every leaderboard refresh.

**Fix** — the rule is already corrected in `firestore.rules`; it just has to be
deployed (see item 3). The Dart side is fixed and needs nothing from you.

Note the app only publishes scores for children with **leaderboard opt-in
enabled** on their profile. If no profile has it on, an empty board is correct
behaviour, not a bug.

---

## 3. Deploying rules and indexes

Both `firestore.rules` and `storage.rules` are in the repo but are only live once
deployed.

```bash
firebase deploy --only firestore:rules,storage
```

`firestore.indexes.json` still declares a composite index on the leaderboard
`entries` collection. The app no longer needs it — the query was reduced to a
single `orderBy` that runs on Firestore's automatic index — so deploying it is
optional:

```bash
firebase deploy --only firestore:indexes   # optional
```

---

## 4. The Firebase CLI on this machine is broken

**Symptom** — any `firebase` command dies with:

```
Error: ENOENT: no such file or directory, open
'.../lib/node_modules/firebase-tools/lib/templates/hosting/init.js'
```

**Cause** — a partially installed `firebase-tools` under the Herd-managed Node
(`v22.12.0`). The package directory is missing its `templates` folder.

**Fix**

```bash
npm uninstall -g firebase-tools
npm install -g firebase-tools
firebase login
firebase use little-learner-9d2f1
```

You need this working before items 2 and 3 can be done.

---

## 5. iOS is not configured for Firebase

**Symptom** — the app builds and runs on Android but Firebase features fail or
crash on an iOS device or simulator.

**Cause** — `ios/Runner/GoogleService-Info.plist` does not exist. Only the
Android side (`android/app/google-services.json`) was ever added.

**Fix**

1. Firebase console → Project settings → **Add app → iOS**, using the bundle id
   from `ios/Runner.xcodeproj`.
2. Download `GoogleService-Info.plist` into `ios/Runner/`.
3. Add it to the Runner target in Xcode so it ships in the bundle.

Alternatively run `flutterfire configure`, which writes a
`lib/firebase_options.dart` covering every platform at once. The project does not
currently have that file — `Firebase.initializeApp()` relies on the per-platform
config files instead.

---

## 6. Audio cues are silent

**Symptom** — the speaker button on activity cards and the Koala guide never
plays anything.

**Cause** — `assets/audio/learning/` and `assets/audio/koala/` are declared in
`pubspec.yaml` but are empty. Every `audioCueKey` in `lib/data/seed_content.dart`
(for example `trace_letter_a`, `english_apple`) points at a file that was never
recorded.

**Fix** — drop `<cueKey>.mp3` files into the matching folder. The player resolves
`audioCueKey` to `assets/audio/learning/<cueKey>.mp3` and fails quietly when the
file is absent, so this degrades gracefully and can be filled in over time.

---

## 7. Video lessons point at a placeholder clip

**Symptom** — every video lesson plays the same butterfly clip.

**Cause** — `videoUrl` in the video levels points at
`flutter.github.io/assets-for-api-docs/.../butterfly.mp4`, a Flutter sample asset
used as a stand-in.

**Fix** — replace the `videoUrl` values in `lib/data/seed_content.dart` with real
lesson URLs, or upload the lessons to Firebase Storage and use their download
URLs. **Bump `bundledContentRevision` at the top of that file** when you do, or
devices that already ran the app will keep the old content.

---

## Editing bundled content

Not a bug, but the thing most likely to waste your time.

The local SQLite database is seeded from `lib/data/seed_content.dart` **once**.
Edits to that file never reach a device that has already run the app unless
`bundledContentRevision` changes. The repository compares the stamp on launch and
reinstalls the bundle when it differs, keeping level progress and downloaded
flags intact.

So: **every time you touch `seed_content.dart`, bump `bundledContentRevision`.**
