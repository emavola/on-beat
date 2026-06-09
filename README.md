# 🥁 OnBeat

**OnBeat** is a rhythm-training app for Flutter. Pick a tempo, choose how you want
to play, and keep time by **tapping the beat** — either by moving your phone
(accelerometer) or by making a sound (microphone). OnBeat listens, scores every
beat against the metronome, and tells you how tight your timing really is.

It even reads rhythms straight off a sheet: snap a photo of a simple rhythm line
and the built-in **rhythm scanner** turns it into a playable exercise.

---

## ✨ Features

- **Five practice modes**
  - **Normal** – play a set exercise, pass/fail on accuracy
  - **Zen** – open-ended practice, no pressure, just keep playing
  - **Incremental** – tempo ramps up the longer you stay on beat
  - **Survival** – limited lives; miss too many and it's over
  - **Challenge** – a fixed scripted piece (also where scanned rhythms land)
- **Three difficulties** – Easy / Medium / Hard
- **Two ways to play** – Accelerometer (tap/move the device), Microphone (clap,
  tap a surface), or **Mixed** for both at once
- **Adjustable tempo** – per-mode BPM defaults you can dial up or down
- **Live scoring** – every quarter-note is evaluated and animated in real time
- **Calibration** – audio-latency tap-along + sensor-threshold tuning so timing
  is fair on any device
- **Rhythm scanner** – pick an image of a rhythm and play it back as an exercise
- **Stats & profile** – sessions are saved and charted over time
- **Cloud sync** – anonymous sign-in + Firestore, so your history follows you

---

## 📱 Storyboard & architecture

A visual walkthrough of the screens, the navigation graph, and the app
architecture lives in:

```
docs/storyboard/OnBeat_storyboard.pdf
```

---

## 🧭 App flow

```
Home ──▶ Exercise Setup ──▶ Exercise ──▶ Result ──┐
  │         (mode, difficulty,           ▲         │ Retry
  │          BPM, sensor)                └─────────┘
  │
  ├──▶ Scan a Rhythm ──▶ (Challenge) Exercise
  │
  └──▶ Bottom nav: Home · Profile · Stats · Settings
                                          │
                                          └──▶ Calibration · Sensor tests
```

---

## 🏗️ How it's built

OnBeat follows a layered structure:

| Layer | Folder | Responsibility |
|-------|--------|----------------|
| **UI** | `lib/screens`, `lib/pages`, `lib/widgets` | Tabs, full-page flows, reusable widgets |
| **Navigation** | `lib/navigation` | Named routes + router |
| **Controllers** | `lib/controllers` | Exercise & measure logic / state |
| **Services** | `lib/services` | Sensors, microphone, metronome, scanner, auth, persistence |
| **Models** | `lib/models` | Measures, quarters, results, session documents |
| **Theme** | `lib/themes` | Colors, text styles, app theme |

**Tech:** Flutter · `sensors_plus` · `audioplayers` · native mic onset detection
(MethodChannel) · `image` / `image_picker` (rhythm scanner) · `fl_chart` ·
`shared_preferences` · Firebase (Core, Auth, Cloud Firestore).

---

## 🚀 Getting started

```bash
flutter pub get
flutter run
```

**Requirements**
- Flutter SDK `^3.7.2`
- A Firebase project configured for the app (Auth + Firestore)
- A physical device is recommended — the accelerometer and microphone don't
  work on most emulators

---

*Built as a university project. 🎓*
