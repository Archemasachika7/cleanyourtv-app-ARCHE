# Arche: the Iron Monarch look

This fork's own changes on top of Clean Your TV. On the TV home screen they give you:

- **"GOOD MORNING, ARCHI"** (afternoon, evening, night as the clock moves) in gold above the clock.
- **The Iron Monarch wallpaper**: an original hooded iron mask in emerald and gold, drawn in code
  (`tools/make_wallpaper.py`, 38 KB). It's the default picture for a TV this phone hasn't set up yet,
  and you can pick it any time in the phone app under Look → Picture. A new TV starts in the
  **Glass** style: a frosted-glass dock, round buttons in the top bar and a glowing focus ring.
- **A different colour for every app**: the focus ring and the glow behind the dock take the focused
  app's own colour, so moving from Netflix to YouTube to Prime turns the glow red, then white, then
  blue. For a bigger change in "perspective", choose the **Spotlight** style in Look: the focused app's
  artwork then fills the top of the screen.
- **Inputs and your apps up front**: the Inputs pill stays in the top bar and the apps form the dock row.
- **A startup sound**: an original 4.6 s brass-and-timpani swell (`tools/make_sound.py`, 14 KB Ogg) when
  Home first comes up after the TV is switched on. It plays once per boot, so pressing Home stays quiet.
- **Light**: the sound player is released as soon as it finishes, the picture is small, and the phone
  app still picks Quick movement on TVs with little memory.

The Marvel music and Doctor Doom artwork are copyrighted, so neither is in this repo. You can use your
own clip on your own TV (see "Your own sound" below).

## Install

1. Open the latest **Arche Doom build** under this repo's [Releases](../../releases) on your Android
   phone and download `arche-phone.apk`. Install it (allow "install unknown apps" for your browser
   when Android asks). If the official Clean Your TV app is on the phone, keep it or remove it; this
   build installs beside it as a debug app.
2. Open it and follow the steps: switch on network debugging on the TV with the remote, then
   connect, analyse and clean. The app installs the Arche TV launcher (`arche-tv-launcher.apk` is
   bundled inside it) and makes it Home.
3. **If the official Clean Your TV home screen is already on the TV**, it's signed with a different
   key, and Android won't install the Arche one over it. Remove it first with
   `adb uninstall com.gathin.tvhome`, or with "Undo everything" in the official app.

## App symbols and AI tiles

Each tile shows the app's own symbol (the icon from the app on your TV) on a glass card in the
app's colour. A new TV starts like this; in the phone app, Look → More options → App tiles → "The app's own art" switches
back to the apps' wide banners.

Right after your entertainment apps comes a row of AI assistants: **Claude, ChatGPT, Gemini and
Perplexity**. Each tile opens the assistant's app if it's installed on the TV; none of them has
a TV app today, so it opens the website (claude.ai, chatgpt.com, gemini.google.com,
perplexity.ai) in the TV's browser. Many Google TVs ship without a browser; if the tile says so,
install one from the Play Store (for example "TV Bro"). The symbols are drawn in code: the
assistant's initial on its colour, with a small spark.

To choose your own list, add `"ai_tiles"` to the theme's `config.json`, one
`"Name|package|https://site"` per tile (up to 8), or `[]` to hide the row:

```json
"ai_tiles": ["Claude|com.anthropic.claude|https://claude.ai", "Perplexity|ai.perplexity.app.android|https://www.perplexity.ai"]
```

## Vibes: a picture per app

Give every app its own picture. Move Left or Right through the dock and the whole background
crossfades to that app's vibe: the first app gets the first picture, the second app the second,
and so on, wrapping round when you have more apps than pictures.

The pictures are your own files on your own TV and are never part of this repo. Name them in the
order you want (`01-….jpg`, `02-….jpg`, …), about 1920x1080 and under 400 KB each, then:

```bash
tv/arche/push-vibes.sh <tv ip> path/to/vibes
```

To go back to the single wallpaper:

```bash
tv/arche/push-vibes.sh <tv ip> --clear
```

It stays light: one picture is decoded at a time, at screen size in 16-bit colour, and only once
the focus has rested for 0.22 s, so scrolling fast through the dock decodes nothing in between.
Each picture is darkened 35% so names and the clock stay readable. In the theme's `config.json`,
`"vibe_dim"` (0 to 90) changes the darkening and `"vibe_delay_ms"` (0 to 2000) the wait.

## Your own sound

Copy a short clip (under 15 s) to the TV as `startup_sound.ogg` (or `.mp3`, `.m4a`, `.wav`):

```bash
adb push my-intro.mp3 /sdcard/Android/data/com.gathin.tvhome/files/startup_sound.mp3
```

To change when it plays, add `"startup_sound": "always"` (every time Home opens) or `"off"` to the
theme's `config.json`. The default is `"boot"`.

## How it's built

`.github/workflows/arche.yml` runs `build-arche.sh` on every push to this branch:

1. `launcher/arche-launcher.patch` and `launcher/res/` go onto the upstream launcher in
   `third_party/cleanyourtv`: `StartupSound.java`, the default `greeting_name` "Archi", the gold
   greeting, and version 3.0-arche (versionCode 10, one above the official 3.0).
2. The launcher is built and signed with your key (the secrets below).
3. Its sha256, size and signer are written into `PinnedLauncher` (`core/trust/.../Pins.kt`), and the
   APK replaces the bundled one, so the phone app trusts and installs it.
4. The phone app's full debug build is assembled. Both APKs go into a pre-release.

### Your signing key (do this once)

Without a key, every build signs the TV launcher with a new throwaway key, so updating the TV
later means `adb uninstall com.gathin.tvhome` first. To keep one key, run this once on a computer:

```bash
keytool -genkeypair -storetype PKCS12 -keystore arche.p12 -alias arche -keyalg RSA -keysize 3072 -validity 10000 -dname "CN=Arche TV launcher"
```

```bash
base64 -w0 arche.p12
```

Then in GitHub go to the repo's Settings → Secrets and variables → Actions and add
`ARCHE_KEYSTORE_B64` (the base64 output) and `ARCHE_KS_PASS` (the password you chose). Keep
`arche.p12` private and never commit it.
