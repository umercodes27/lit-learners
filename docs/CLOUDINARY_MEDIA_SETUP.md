# Media uploads with Cloudinary

Firebase Storage will not accept an upload until the Firebase project has a
billing account. Cloudinary's free tier takes images, audio and video with no
card, so the admin media library can store files there instead.

Only the **files** move to Cloudinary. The media library records (who
uploaded what, for which module) and the picture addresses on cards and quiz
questions still live in Firestore, exactly as before.

## 1. Create an unsigned upload preset

1. Sign up at cloudinary.com (free plan).
2. On the dashboard, note your **Cloud name**.
3. Settings → **Upload** → **Upload presets** → **Add upload preset**.
4. Set **Signing mode** to **Unsigned**. Name it, for example
   `little_learners_unsigned`.
5. Recommended, because an unsigned preset can be used by anyone who knows its
   name:
   - **Allowed formats**: `png, jpg, jpeg, webp, gif, mp3, wav, m4a, mp4`
   - **Max file size**: something sensible, such as 20 MB
6. Save.

## 2. Run the app with it

Both values are passed at build time, not written in the code:

```sh
flutter run -d chrome \
  --dart-define=USE_FIREBASE=false \
  --dart-define=CLOUDINARY_CLOUD_NAME=your-cloud-name \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=little_learners_unsigned
```

For a phone build, add the same two `--dart-define` flags to
`flutter build apk`. They work with Firebase on or off.

Without them the app falls back to Firebase Storage (Firebase on) or to
in-memory storage (Firebase off). In-memory pictures get a `memory://` address,
which the level editor warns about: they will not show on a phone.

## 3. Using pictures

- **Content → open a module → Edit** (pencil) on any level, or **New level**.
- Every card and every quiz question has a **Picture** row. **Choose** opens
  the media library for that module: pick an existing picture, **Upload a new
  picture**, or paste an `https://` link.
- Pictures show above the card's words, and above a quiz question's answers.
  If a picture cannot load, the card still shows its words.
- AI-generated levels never invent pictures. Add them in the draft's
  **Edit this level** section before approving.

## Things to know

- **Never put the Cloudinary API secret in the app.** Unsigned presets exist so
  that it is not needed.
- **Deleting from the media library does not delete the file from
  Cloudinary** — that needs the API secret. Remove it in the Cloudinary console
  if it matters.
- Children need a connection to see a picture the first time it loads.
