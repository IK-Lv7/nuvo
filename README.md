<p align="center">
  <img src="Sources/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="120" alt="Nuvo app icon">
</p>

<h1 align="center">Nuvo</h1>

<p align="center">
  <b>Beautiful photos. Completely free. Entirely on your device.</b>
</p>

<p align="center">
  English · <a href="README.ja.md">日本語</a>
</p>

---

Nuvo is a photo editor for iPhone that helps portraits look like you on your best day — with no subscription, no watermark, no ads, and no account.

> **Status:** In development. Nuvo is in TestFlight testing and is not on the App Store yet.

## Everything is free. Really.

No subscription. No one-time purchase. No "Pro" tier. No watermark. No daily limits.
Every tool is open from your very first tap.

Why? Retouching runs on your phone's own chip, so it costs us almost nothing to run. We don't think you should pay a monthly fee for something your phone already does.

## Your photos stay yours

- **Nothing leaves your phone.** Nuvo doesn't connect to the internet.
- **No account.** No sign-in, no sign-up.
- **No ads, no analytics, no trackers.**
- **We collect nothing**, so there is nothing to leak, sell, or lose.
- Sharing uses the standard iOS share sheet — you choose where a photo goes.

## What you can do

**Natural-looking skin**
Smooth skin, brighten it, add a healthy glow, and fade dark circles. Nuvo keeps your skin's texture instead of blurring it flat, and every effect has a built-in limit so even the maximum setting doesn't look plastic. Blemishes can be fixed with a tap, or found automatically.

**Face and features**
Slim the face, enlarge the eyes, refine the chin, and shape the nose — following your own facial features, not a generic template.

**Makeup**
Lipstick, blush, brows, and teeth whitening that stay put on your face and keep the natural highlights and texture underneath.

**Backgrounds and ID photos**
Blur or replace the background. Portrait Mode photos use their built-in depth data for a more natural blur. Make an ID photo with one tap: 35 × 45 mm (passport / My Number card) or 30 × 40 mm (résumé).\*

**Composition, text, and filters**
Crop, rotate, straighten, and zoom in. Add text in a range of typefaces. Choose from 18 filters, then add film grain or a soft light leak.

**Make it yours**
Save your favorite settings as a *Look* and apply it to any photo — or to many photos at once.

**Export your way**
Save as JPEG, HEIC, or PNG at the quality you want. Location data can be removed from exported photos (on by default). Your original photo is never changed.

<sub>\* The ID photo layouts follow the published guidelines for Japanese passport and My Number card photos. Always check the requirements of wherever you submit the photo.</sub>

## Made to look like you

Editing should make you look like the best version of yourself, not like a different person. Nuvo is tuned for restraint: gentle skin smoothing that keeps texture, natural-looking limits on every effect, and an easy press-and-hold to compare with your original at any time.

## Requirements

iPhone with iOS 17 or later. Available in English and Japanese.

## Feedback

Found a bug, or want to tell us how a result looks? [Open an issue](../../issues/new/choose) — there are short forms for **bugs**, **results that look unnatural**, **general feedback**, and **feature ideas**. A free GitHub account is all you need. Please don't attach personal photos.

## For developers

Nuvo is written in Swift and SwiftUI on top of Apple's own frameworks (Core Image, Vision, Photos), with **no third-party dependencies**.

- The project's principles and rules are in [AGENTS.md](AGENTS.md); see also [CONTRIBUTING.md](CONTRIBUTING.md). The rules are checked automatically by `scripts/check_policy.py`.
- The app project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml`; the core library can be tested with `swift test` on a Mac.
- [`prototype/`](prototype) is a throwaway Expo mockup used to iterate on the interface. It is not part of the app.
