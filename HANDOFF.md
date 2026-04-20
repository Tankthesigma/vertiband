# VertiBand — Project Handoff

> Last updated: 2026-04-19
> For a Claude Code session on another machine picking this project up mid-stream.
> Nothing here is secret. API keys and passwords are referenced by *where* to find them, never the values.

## 1 · What this project is

**VertiBand** — a head-worn wearable + companion software for guiding patients
through the Epley maneuver, a treatment for benign paroxysmal positional vertigo
(BPPV). The system verifies each stage of the maneuver in real time using a
9-axis IMU at 100 Hz, gives adaptive audio cues, and logs every session.

Built by **Zavier** (hardware lead) and **Tanmay** (software lead). High-school
founders. Going to the American Audiology conference, needs to look and feel
like a $50M company.

Brand voice is **clinically confident**: short declarative sentences, specific
numbers over adjectives, no emoji, no exclamation marks.

## 2 · What's shipped

| Piece | Where it lives | Status |
|---|---|---|
| **Marketing site** | `index.html` + `tokens.css` + `assets/` + `for-clinicians.html` + `live-gyro.html` | Live at **`https://vertiband.us`** |
| **iOS companion app** | `ios/` (SwiftUI 5, iOS 17+, XcodeGen) | Code complete, unbuilt (needs Xcode on a Mac) |
| **Raspberry Pi firmware** | On the Pi at `~/vertiband/` — NOT in this repo | Running, systemd-managed |
| **TTS control panel** | On the Pi at `~/vertiband/tts_panel.py` | Running as systemd service on port 5060 |
| **Gemini prompts** | `prompts.md` + several Veo 3 video prompts in chat history | Two hero videos rendered into `assets/hero-film.mp4` + `hero-film-2.mp4` |

## 3 · Git / Vercel / domain

- **GitHub**: <https://github.com/Tankthesigma/vertiband> (account `Tankthesigma`)
- **Branch**: everything on `main`. No PRs yet.
- **Vercel**: project named `vertiband`, auto-deploys every push to `main`. Takes ~20 s.
- **Domain**: `vertiband.us` (Porkbun), linked to Vercel via DNS records:
  - `A` `@` → `76.76.21.21`
  - `CNAME` `www` → `cname.vercel-dns.com`
  - SSL auto-issued by Vercel. Both apex and `www` work.
- **`gh` CLI** on the Windows machine is already authenticated as `Tankthesigma`
  with `repo` + `workflow` scopes. On the Mac you may need `gh auth login` once.

## 4 · Raspberry Pi infrastructure

Physical device is the VertiBand prototype. Runs a Raspberry Pi 4 (Raspbian 12
bookworm, 2 GB RAM) with an MPU6050 IMU on I²C bus 1 at `0x68`, a PiSugar
battery at `0x32`, and audio over the 3.5mm jack → external amp → speaker.

- **LAN IP**: `192.168.254.53` (joined `KINETIC_f798e0` Wi-Fi)
- **SSH user**: `zavierhayat`, password: `password` (lowercase, as of 2026-04-17).
  The SSH pubkey at `~/.ssh/id_ed25519.pub` on the Windows machine is already
  in `zavierhayat@raspberrypi:~/.ssh/authorized_keys` — key auth works.
- **Also on the Mac**, to enable key auth from there: run once on the Pi
  `cat >> ~/.ssh/authorized_keys` and paste the Mac's pubkey.

### Services running on the Pi (all systemd, enabled for auto-boot)

| Service | Unit | Port | Purpose |
|---|---|---|---|
| TTS panel | `vertiband-tts-panel.service` | 5060 | Flask UI to type text → Google Cloud TTS → Pi speaker. Open `http://192.168.254.53:5060` on LAN. |
| EEE-off on eth0 | `eth0-no-eee.service` | — | Keeps Ethernet awake (fixes Pi disconnect bug) |
| avahi cron | `/etc/cron.d/avahi-refresh` | — | Restart avahi every 5 min so `raspberrypi.local` stays resolvable |

### Environment on the Pi

- `GOOGLE_CLOUD_PROJECT=vertiband-1776463837`
- `GOOGLE_CLOUD_LOCATION=us-central1`
- ADC credentials: `~/.config/gcloud/application_default_credentials.json`
  — authenticated as `puneethere2002@gmail.com` (has $300 + $1,000 GCP credits)
- Python venv: `~/vertiband-env/`
- Project source: `~/vertiband/` (NOT in git, lives only on the Pi)

### Key files on the Pi (in case they need to move here)

```
~/vertiband/
├── config.py         ← tolerances, sample rates, Epley step tables
├── imu.py            ← MPU6050 driver + complementary filter
├── state_machine.py  ← original Epley state machine
├── sway.py           ← biomarker math
├── nystagmus.py      ← gyro-band nystagmus detector
├── vertiscore.py     ← composite 0-100 score
├── predictor.py      ← recovery probability logistic regression
├── simulate.py       ← virtual-patient simulator
├── ai_coach.py       ← Gemini via Vertex AI
├── tts.py            ← Google Cloud Chirp3-HD wrapper, 10 languages
├── session_log.py    ← JSON session logger
├── report.py         ← HTML report generator with matplotlib plots
├── vertiband_main.py ← main orchestrator (full session)
├── dashboard.py      ← conference-booth Flask live dashboard
├── tts_panel.py      ← TTS control panel (the one that's systemd-managed)
├── play_random.py    ← quick one-shot speaker test
├── logs/sessions/    ← session JSON + HTML reports
└── archive/          ← 13 legacy vertiband_*.py / server_*.py files
```

## 5 · Marketing website — `/index.html`

Paper-cream canvas + ink-navy text + warm terracotta accent. Fraunces display,
Inter body, JetBrains Mono for telemetry. **No motion library dependencies
beyond GSAP + ScrollTrigger + Lenis, all from CDN.**

Section order: `home (film) → overview → problem → marquee → device → method →
marquee → compare → app → evidence → press → team → reserve → faq`.

Hero is a 2-clip crossfade — `assets/hero-film.mp4` and `assets/hero-film-2.mp4`,
both ~10 s seamless loops, crossfade rotation with scale+alpha handoff so
clip B appears to "stem from" clip A.

Sibling pages:
- `live-gyro.html` — phone DeviceOrientation demo; iPhone on forehead = sensor
- `for-clinicians.html` — research brief + SOAP note sample + JSON schema

## 6 · iOS app — `/ios/`

SwiftUI 5 / iOS 17+. Uses the `@Observable` macro. Zero third-party deps.
XcodeGen generates the `.xcodeproj` from `ios/project.yml`.

### First-run on the Mac

```sh
cd ios
./bootstrap.sh        # installs xcodegen via brew if missing, generates project, opens Xcode
```

In Xcode: Signing → pick Apple ID → plug in iPhone → ⌘R.

### Architecture

- `VertiBandApp.swift` — @main, injects services via `.environment`
- `RootView.swift` — onboarding gate + TabView (Home, History, Settings)
- `Theme/` — tokens + reusable components
- `Models/` — `EpleyConfig`, `SessionRecord`
- `Services/` — `MotionService` (CoreMotion 50 Hz), `AudioService` (AVSpeech +
  sine pacing beeps), `GeminiService` (REST to v1beta/generateContent, key in
  keychain), `PiBridge` (optional HTTP to Pi port 5060), `SessionStore`
  (UserDefaults JSON)
- `Session/SessionEngine.swift` — Epley state machine + VertiScore
- `Features/` — Onboarding, Home, PreSession, Session, Complete, History, Settings

### Features the user configures in Settings tab

- Language (10 langs), voice gender
- Gemini API key (free from `aistudio.google.com/app/apikey`) — unlocks live
  hints + post-session AI note
- Pi URL (e.g. `http://192.168.254.53`) — when set, voice cues route to the
  band's amp via the TTS panel. Leave blank for phone-only.

### Known gaps / open issues in the iOS app

- `PoseCanvas.swift` animation modifier is on the wrong view in one spot; pose
  dot may not animate as smoothly as intended. Minor visual only.
- Navigation chain: `Home → PreSession cover → Session cover → Complete cover`.
  Dismissing Complete returns to PreSession, not Home. Hit X in PreSession to
  close. Fine for demo, fix later with a unified NavigationStack.
- App icon is a single 1024×1024 placeholder. No real icon asset yet.
- No AppStore submission pipeline. Sideload-to-own-device only.

## 7 · Brand tokens (identical on web + iOS)

```
paper      #F4F1EC   page background
paper2     #ECE8E1   card hover / tint
ink        #0F2341   primary text
signal     #C85A3A   one accent color (warm terracotta)
success    #3ACF8E
warning    #E5B93A
danger     #E5624F
cyan       #5ED4E5   (dark-UI accent only — app Session runner)

Fraunces — display (web Fraunces; iOS uses system serif as fallback)
Inter — body
JetBrains Mono — telemetry
```

Radii: 10–20 px cards, 999 px pills. Hairlines `rgba(29,44,56,0.10)`.
No gradients, no neon, no glowing LEDs on device images.

## 8 · Credentials (where to find them — values NOT in this file)

| Thing | Where |
|---|---|
| Pi SSH password | Chat history; 2026-04-17 message from Zavier |
| Pi Wi-Fi password | Inferred from Windows via `netsh wlan show profile` on `sigmapc` |
| Gemini API key | Not yet created. Use `aistudio.google.com/app/apikey` |
| GCP project | `vertiband-1776463837`, owner `puneethere2002@gmail.com` |
| GCP billing | Account `01E641-8FFDF1-D5877D`, $262/$300 free trial + $1000 GenAI App Builder credit |
| GitHub token | Stored in `gh` CLI keyring as `Tankthesigma` |
| Porkbun API | Not set up. Domain DNS managed manually through porkbun.com |
| Apple Developer | Free-tier Apple ID on Tanmay's Mac only |

## 9 · Open threads / next obvious moves

- **Get Xcode installed** on the Mac (blocker). Disk is currently 16 GB free;
  Xcode needs ~40 GB. Free space first.
- **Build iOS app on device** once Xcode is ready. Follow `ios/bootstrap.sh`.
- **Fill the final VertiBand site gaps**: real clinician-quote content (current
  quotes are placeholders), App Store badge once an .ipa exists.
- **Generate one more Veo hero clip** — user wanted 3 clips total at one point.
  Two are in `assets/`. Prompts for clips B and C are in chat history.
- **Optional: add the PWA manifest** to the marketing site so the web app can
  install to home screen on Android while iOS app ships.
- **Research-grade add-on**: real-time nystagmus detection from gyro — prototype
  exists on the Pi in `~/vertiband/nystagmus.py`, not yet clinically validated
  (MPU6050 noise floor is marginal in the 1–3 Hz band).

## 10 · Working style notes for the next Claude session

- User prefers terse responses. Short sentences, concrete actions.
- User is going to conference demos; polish matters more than feature count.
- When asked "search online," run a WebSearch + cite sources with markdown links.
- When giving Gemini / Veo prompts, always include HARD NEGATIVES and a LOOP
  CONTRACT line — that's what makes Veo cooperate.
- User sometimes types fast + typos; read past them to intent.
- User on Windows locally. Mac is remote via SSH at `tanmaydagoat@192.168.254.245`
  on the same Wi-Fi as the Pi. Mac username `tanmaydagoat`.
- For the Pi: always ping first before SSH — Ethernet connection dropped often
  early in the project until we moved to Wi-Fi and installed the systemd services.

## 11 · Fast commands

```sh
# verify everything is alive
ping -n 2 192.168.254.53                  # Pi
curl -sS -o /dev/null -w "%{http_code}\n" https://vertiband.us    # site
ssh zavierhayat@192.168.254.53 'systemctl is-active vertiband-tts-panel'

# make a change and ship it
cd ~/vertiband-site  # or wherever this repo is
# edit files
git add . && git commit -m "msg" && git push
# Vercel auto-deploys in ~20 s

# iOS dev
cd ios && ./bootstrap.sh     # generates Xcode project + opens it
```

---

Good luck, next session. The hardware works, the site is live, the app code is
written — you're picking up at a clean handoff point.
