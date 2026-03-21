# wthrr Monetization Spec

## Price: $4.99 one-time license — direct sales, no App Store

---

## Distribution Strategy — Option A (Chosen)

### Public GitHub + thedubes.com/wthrr + LemonSqueezy

This is the recommended strategy. All three pieces work together:

| Component | Role |
|-----------|------|
| **Public GitHub repo** (`todddube/wthrr`) | Credibility, discoverability, releases, issue tracking |
| **Private GitHub repo** (`todddube/wthrr_mac`) | All source code — never public |
| **thedubes.com/wthrr** | Sales landing page — video, download, buy button |
| **LemonSqueezy** | Payment, license key delivery, tax compliance |

---

### Two-Repo Strategy: Private Source, Public Presence

The source code stays private. The public repo is a marketing shell.

**Private repo: `todddube/wthrr_mac`** *(this repo)*
- All Swift source code lives here
- Build, sign, and notarize locally using your Apple Developer ID
- Upload the finished `.dmg` artifact to the public repo's GitHub Releases
- Never exposed — no one sees the implementation

**Public repo: `todddube/wthrr`**
- No source code — marketing and distribution only
- Contains: `README.md` (features, screenshots, download link), `CHANGELOG.md`, `LICENSE`
- GitHub Releases hosts the signed `.dmg` binaries for each version
- Issues enabled for bug reports and feature requests
- This is the URL you share everywhere: Product Hunt, Reddit, press pitches, thedubes.com/wthrr

**Why this works:**
- Discoverability and credibility of an open presence without exposing source
- GitHub Releases is the standard distribution mechanism for direct-sale Mac apps — users trust it
- You control exactly what the public sees
- This is how most successful paid indie Mac apps handle it (Raycast was private for years, many others still are)

---

### Naming Convention

| Thing | Name |
|---|---|
| App | **wthrr** |
| Public GitHub repo | `github.com/todddube/wthrr` |
| Private GitHub repo | `github.com/todddube/wthrr_mac` *(existing)* |
| Sales landing page | `thedubes.com/wthrr` |
| LemonSqueezy product | `wthrr — Weather Effects for Mac` |
| `.dmg` filename | `wthrr-1.0.0.dmg` *(semver, matches MARKETING_VERSION)* |
| Bundle identifier | `com.thedubes.wthrr` *(or current value — keep consistent)* |

---

---

### Why Public GitHub (Not Private)

A public repo is almost always the right call for a paid indie app:

- **Free marketing** — developers discover it, star it, share it on Hacker News and Twitter
- **Credibility signal** — shows the app is real, maintained, and not abandonware
- **Open source ≠ free** — you can have a public repo and still sell the app. Most people pay for convenience, updates, and trust — not the source code itself
- **Launch platforms need a link** — Product Hunt, Hacker News Show HN, and Reddit posts all benefit from a live repo to point to
- **wthrr's value is the experience**, not proprietary algorithms — the code being visible does not undermine the sale

**Private repo** is only justified when the code itself is the competitive moat. That's not the case here.

---

### Why Not the Mac App Store

The App Store would actively hurt wthrr:

- **30% cut** on every $4.99 sale — you'd keep $3.49 instead of ~$4.24 via LemonSqueezy
- **Sandbox restrictions** — borderless overlay windows and global hotkeys are difficult or impossible under the App Store sandbox. The app architecture would need a significant rewrite
- **Review delays** — every update waits days for Apple approval
- **No trial model** — App Store doesn't support the 14-day full trial → 10-minute session model
- **No direct customer relationship** — you can't email customers, offer discount codes, or handle license recovery easily

**Decision: Direct distribution only.**

---

### GitHub Repo Setup

1. Create public repo: `github.com/todddube/wthrr_mac`
2. The existing `README.md` is your repo landing page — it already documents all features, architecture, and building instructions
3. Add a prominent **Download / Buy** badge at the top of the README linking to `thedubes.com/wthrr`
4. Use GitHub Releases to host signed `.dmg` files for each version
5. GitHub Issues for public bug tracking and feature requests — this builds community and trust

**README badge to add (top of README, below the title):**
```markdown
[![Download](https://img.shields.io/badge/Download-thedubes.com/wthrr-blue)](https://www.thedubes.com/wthrr)
[![Price](https://img.shields.io/badge/Price-%244.99%20one--time-green)](https://www.thedubes.com/wthrr)
```

---

### thedubes.com/wthrr — Sales Landing Page

This page is the single place you send everyone: Product Hunt, Reddit, Twitter, press. It handles both download (free trial) and purchase.

**Page structure:**

**Above the fold:**
- Looping autoplay MP4 (not GIF — 85% smaller file, same effect) of weather on a real desktop
- Headline: `"Animated Weather Effects for Your macOS Desktop"`
- Subheadline: `"Snow. Rain. AI Storms. Aurora. Across all your displays. $4.99 lifetime."`
- One CTA button: **"Download Free Trial"** (links to latest `.dmg` on GitHub Releases)

**Modes section:**
- Three side-by-side GIFs: snow, rain, AI storm
- Short one-line description per mode

**Features section:**
- Multi-display screenshot
- Bullet list: 9 presets, live weather, seasonal awareness, fully customizable

**Social proof (add post-launch):**
- Product Hunt badge
- Reddit/Twitter quotes
- Download count

**Pricing section:**
- `"$4.99 — One-time purchase. Works forever. No subscription."`
- "Buy License" button → LemonSqueezy checkout page
- "Already have a key? Activate in the app."

**Footer:**
- Download link, support email, GitHub link, `© Todd Dube — thedubes.com`

**Hosting:** GitHub Pages (`todddube.github.io/wthrr`) with a custom domain redirect from `thedubes.com/wthrr`. Free, no maintenance.

---

### LemonSqueezy Product Configuration

1. Sign up at lemonsqueezy.com (free)
2. Create store: "Todd Dube" or "thedubes"
3. Create product: `"wthrr — Weather Effects for Mac"`
4. Price: $4.99 USD, one-time
5. License key settings: **3 activations per key** (covers user's MacBook + desktop + spare)
6. Delivery: Automatic license key via email on purchase
7. Checkout URL: Embed on thedubes.com/wthrr as the "Buy License" button destination
8. Configure webhook (optional): Notify your server on purchase for analytics
9. Set up discount codes: `LAUNCH` (40% off for launch week = $2.99), `BLACKFRIDAY` (same)

**Test before launch:** LemonSqueezy has a test mode — complete a full purchase flow end-to-end and verify the license key activates correctly in the app before going live.

---

## How Other Indie Mac Apps Do It

Before choosing a strategy, here's what works in the wild:

### Shottr (Screenshot tool — $8)
- **30-day free trial**, all features unlocked during trial
- After trial: app still launches but core features are locked
- One license covers **one user on up to 5 Macs**
- Sells direct via website (no App Store)
- Also offers a $30 "Friends Club" tier for experimental features + priority support
- **Takeaway:** Generous trial builds habit → user pays to keep the tool they now rely on

### Bartender (Menu bar organizer — $29)
- **4-week free trial**, fully functional
- License key format: username + alphanumeric key
- Entered in Preferences → Register
- Direct sales via macbartender.com
- Version upgrades require new purchase (paid upgrades)
- **Takeaway:** Even at $29, they give a full month free — confidence in the product

### Hand Mirror (Camera check — Free + $4.99)
- Free base app on the **Mac App Store**
- $4.99 one-time in-app purchase unlocks "Plus" features (Smart Window, Custom Icons, Reactions)
- Free version is fully useful; paid version adds power-user features
- **Takeaway:** Feature-gated freemium works when free tier has clear standalone value

### Ice (Menu bar manager — Free/Open Source)
- Completely free, GPL-3.0 licensed
- Accepts donations via Gumroad
- **Takeaway:** Open source can work, but leaves money on the table for quality indie apps

### Key Pattern
Most successful indie Mac utilities at the $5–$10 range use either:
1. **Time-limited trial → paid license** (Shottr, Bartender) — best for apps where the full experience IS the product
2. **Free tier + paid upgrade** (Hand Mirror) — best when features naturally tier

For wthrr, the full experience IS the product (weather overlays). There's no obvious "free tier" that makes sense on its own. **Time-limited trial is the right model.**

---

## Trial Model (Decided)

### 14-Day Full Trial → 10-Minute Sessions After Expiry

**Days 1–14 (full trial):**
- All features work with zero restrictions — snow, rain, AI storm, all displays, full customization
- On day 10, a subtle banner appears in the popover: *"Trial ends in 4 days — get wthrr for $4.99"*
- No interruptions, no nag screens during the trial period

**Day 15+ (expired, unlicensed):**
- App still launches and runs normally — all features, all modes, all displays
- After **10 minutes**, overlays pause and a purchase prompt appears in the popover
- User can quit and relaunch to get another 10-minute session (per-session timer, not cumulative)
- No hard lockout — the app always works, just in 10-minute windows

**Why this model works:**
- 14-day trial builds the habit — weather effects become part of the user's desktop
- 10-minute post-trial sessions are generous enough to keep the hook alive but short enough to motivate purchase
- Users never feel "locked out" — the app always does something, which keeps it installed (uninstalled apps can't convert)
- The relaunch loop creates mild friction that tips toward buying rather than restarting forever
- Matches the Shottr/Bartender pattern of generous trial → soft limitation

**What the user sees after 10 minutes expire:**
- Overlays fade out (not a hard freeze — smooth stop)
- Popover shows: "10-minute session ended"
- "Activate License" text field + "Activate" button
- "Buy License ($4.99)" button → opens LemonSqueezy product page
- "Quit & Restart" hint — no explicit restart button needed, just relaunch the app

**Implementation:**
- `LicenseManager` stores `trialStartDate` in Keychain (tamper-resistant)
- On each launch: check `daysSince(trialStartDate) > 14 && !isLicensed`
- If trial expired: start a 10-minute countdown timer (600 seconds)
- Timer managed in `LicenseManager`, checked by `WeatherAnimationModel.advance()`
- Per-session only — no persistent timer state needed after the 14-day date check

---

## License Key Platform: LemonSqueezy

**Why LemonSqueezy:**
- **5% + $0.50 per transaction** — on a $4.99 sale you keep ~$4.24
- **Purpose-built license key system:** Each purchase auto-generates a license key with configurable activation limits
- **API for validation:** Simple REST endpoint to verify keys
- **Merchant of record:** Handles global sales tax, EU VAT — you don't deal with tax compliance
- **Modern dashboard:** Manage products, keys, customers, refunds
- **No approval process:** Sign up and start selling immediately

**How it works:**
1. Create LemonSqueezy account → create product "wthrr" at $4.99
2. Configure license key settings: max 3 activations per key (covers multiple Macs)
3. Customer buys → gets license key via email automatically
4. In the app, user enters key → app calls LemonSqueezy API to validate
5. On success, store key in Keychain → app unlocked permanently

**Validation API call:**
```
POST https://api.lemonsqueezy.com/v1/licenses/validate
Body: { "license_key": "<user_key>", "instance_name": "<machine_id>" }
```

**Activation API call (to register a machine):**
```
POST https://api.lemonsqueezy.com/v1/licenses/activate
Body: { "license_key": "<user_key>", "instance_name": "<machine_uuid>" }
```

**Revenue per sale:**
- Price: $4.99
- LemonSqueezy fee: ~$0.75
- **You keep: ~$4.24**

**What LemonSqueezy handles for you:**
- Payment processing (Stripe-backed)
- License key generation + email delivery
- License validation + activation tracking
- Tax compliance (EU VAT, US sales tax — they're merchant of record)
- Refunds (dashboard or API)
- Sales analytics + customer management
- Discount codes and promotional pricing

**What you build:**
- `LicenseManager.swift` — one API call to validate, Keychain storage
- `LicensePromptView.swift` — text field + buttons
- "Buy License" button opens your LemonSqueezy product page in the browser

---

## Implementation Plan

### Phase 1: LicenseManager (~1 day)

```
LicenseManager.swift
├── LicenseState enum:
│   ├── .trial(daysRemaining: Int)        — days 1–14, full access
│   ├── .expired(secondsRemaining: Int)   — day 15+, 10-min session running
│   ├── .sessionEnded                     — 10-min session used up, paused
│   └── .licensed                         — paid, unlimited
├── trialStartDate: Date? (stored in Keychain)
├── storedLicenseKey: String? (stored in Keychain)
├── isLicensed: Bool (computed)
├── trialDaysRemaining: Int (computed)
├── sessionSecondsRemaining: Int (published, for UI countdown)
├── startTrialIfNeeded() — sets trialStartDate on first launch
├── startSessionTimer() — begins 600s countdown (called on launch if trial expired)
├── validate(key:) async -> Result<Void, LicenseError>
│   └── calls LemonSqueezy API, stores key on success
├── checkStatus() -> LicenseState
└── deactivate() — for testing/support
```

**Keychain storage** (not UserDefaults) because:
- Harder to tamper with than plist files
- Survives app reinstalls (persists across updates)
- Encrypted at rest by macOS

### Phase 2: Trial + Session Timer Logic (~0.5 day)

In `WeatherAnimationModel.advance()`:
```swift
switch LicenseManager.shared.state {
case .licensed, .trial:
    // Full access — advance particles normally
    break
case .expired:
    // 10-min session active — advance particles, timer ticking down
    break
case .sessionEnded:
    // Session used up — stop advancing, show purchase prompt
    return
}
```

**14-day trial logic:**
- `trialStartDate` set on first launch via Keychain
- Each launch: `Calendar.current.dateComponents([.day], from: trialStartDate, to: .now).day`
- Days 1–9: No UI indication (let them enjoy it)
- Days 10–14: Subtle banner in popover footer

**10-minute session logic (day 15+):**
- On launch, `LicenseManager` detects trial is expired → starts 600-second countdown
- Timer decrements each second, published for UI to show remaining time
- At 0 seconds: state transitions to `.sessionEnded`, animation pauses
- Timer is per-session only — relaunch resets it (no persistent state needed)

### Phase 3: License Prompt UI (~0.5 day)

**During trial (days 10–14) — soft nudge:**
- Small text in popover footer: "Trial: 4 days remaining · Buy wthrr"
- Non-intrusive, no modals, no blocking

**During expired 10-min session — visible countdown:**
- Popover footer shows: "Session: 7:23 remaining · Buy wthrr"
- All settings still functional, all modes available

**After 10-min session ends — purchase screen in popover:**
- "Your 10-minute session has ended"
- TextField for license key + "Activate" button
- "Buy License ($4.99)" button → opens LemonSqueezy product page
- Hint: "Restart the app for another 10-minute session"
- On successful activation: dismiss prompt, resume overlays, show "Licensed ✓" badge

### Phase 4: LemonSqueezy Setup (~1 hour)

1. Create account at lemonsqueezy.com
2. Create store + product: "wthrr — Weather Effects for Mac"
3. Set price: $4.99, one-time purchase
4. Configure license keys: max 3 activations per key
5. Copy product URL (for Buy button) and API key (for validation)
6. Test in sandbox mode

### Phase 5: Polish (~0.5 day)

- Offline handling: if already licensed, trust Keychain (no API call needed)
- First activation requires internet → show friendly error if offline
- "Licensed" badge in About/footer when activated
- Handle edge cases: invalid key, revoked key, max activations reached
- Support email link in purchase screen for license recovery

---

## Pricing Strategy

**$4.99** is the sweet spot:
- Impulse buy territory for Mac users
- Competitive with Hand Mirror ($4.99), under Shottr ($8), well under Bartender ($29)
- Leaves room for promotional pricing ($2.99 sales)

**Optional:** LemonSqueezy supports "pay what you want" — set $2.99 minimum, $4.99 suggested. Some users pay more, and it signals generosity.

**Discount opportunities:**
- Launch week: $2.99 intro price
- Black Friday / holiday sales: $2.99
- Bundle with future apps if you build more

---

## Distribution

Since we're avoiding the App Store:

### Website + Direct Download
- Host a simple landing page (GitHub Pages, Netlify, or Carrd)
- DMG download with the app inside
- "Buy License" links to LemonSqueezy checkout
- Users drag app to /Applications as usual

### Code Signing & Notarization (Required)
- **Must** sign with a Developer ID certificate (not App Store cert)
- **Must** notarize with Apple — otherwise macOS Gatekeeper blocks the app
- Cost: $99/year Apple Developer Program membership
- Without this, users get scary "unidentified developer" warnings that kill conversions

### Sparkle for Updates
- Use the [Sparkle framework](https://sparkle-project.org/) for auto-updates
- Hosts an appcast XML file on your server/GitHub
- Users get update prompts just like App Store apps
- This is how Shottr, Bartender, and most direct-distribution Mac apps handle updates

---

## Anti-Piracy (Keep It Proportional)

For a $5 app, minimal protection is the right call:

- **Keychain storage** prevents casual UserDefaults editing
- **Server validation on first activation** prevents mass key sharing (LemonSqueezy tracks activation count)
- **3-machine limit per key** is generous for legitimate users, limiting for sharers
- **Don't:** obfuscate code, check on every launch, add aggressive DRM, phone home constantly
- **Philosophy:** If someone pirates a $5 utility, they were never going to pay. Make the purchase experience so smooth that paying is easier than pirating.

---

## Revenue Projections (Napkin Math)

| Scenario | Downloads/mo | Conversion | Sales/mo | Revenue/mo (after fees) |
|----------|-------------|------------|----------|------------------------|
| Modest | 500 | 5% | 25 | ~$106 |
| Good | 2,000 | 8% | 160 | ~$678 |
| Great | 5,000 | 10% | 500 | ~$2,120 |

These assume direct traffic from Product Hunt, Reddit, Twitter/X, Hacker News posts, and word of mouth. The 14-day trial with a $4.99 price point should convert in the 5–10% range based on industry benchmarks for indie Mac utilities.

---

## Marketing & Getting Noticed

### The Core Advantage

wthrr is inherently visual and shareable. Animated snow falling across a triple-monitor setup looks cool in a GIF. That's your entire marketing strategy in one sentence: **make short clips of the effects, put them everywhere.**

---

### Phase 1: Pre-Launch (Weeks 1–8)

#### Build Your Landing Page
Host on GitHub Pages, Netlify, or Carrd (free). Structure:

**Hero section (above the fold):**
- Looping GIF or autoplay video of weather effects on a real Mac desktop
- Headline: "Animated Weather Effects for Your macOS Desktop"
- Subheadline: "Snow. Rain. AI Storms. Across all your displays. $4.99 lifetime."
- Single CTA button: **"Download Free Trial"**

**Demo section:**
- Three side-by-side GIFs: snow, rain, AI storm
- Short description of each mode

**Social proof section (fill in post-launch):**
- Product Hunt badge, Reddit quotes, download count
- "Used by X,XXX Mac users" (update as it grows)

**Pricing section:**
- One line: "$4.99 — One-time purchase. Works forever. No subscription."
- "Buy License" button → LemonSqueezy checkout

**Footer:**
- Download link, support email, Twitter/X link

**Conversion tip:** Research shows changing CTA from "Sign up" to "Try for free" improves conversion ~100%. Lead with the trial, not the purchase.

#### Prepare Visual Assets

You need four types of assets. These get reused across every channel (PH, Reddit, Twitter, landing page, blog pitches), so invest time getting them right once.

**Asset checklist:**
- **GIF clips** — 10–15 seconds each, one per weather mode (snow, rain, AI storm), plus one multi-display shot
- **MP4 demo video** — 60–120 seconds, full walkthrough: launch app → toggle modes → adjust settings → multi-display
- **Screenshots** — 4–6 clean stills showing each mode + the popover UI + multi-display
- **Device mockups** — screenshots framed inside MacBook/Studio Display for landing page hero

---

#### How to Record GIF Clips

**Recommended tool: CleanShot X ($29 one-time)**
Best all-in-one for indie Mac devs — records GIFs and video, hides desktop icons during capture, includes annotation and instant sharing. This is what most indie Mac developers use.

**Free alternative: Kap (open source)**
Exports to GIF, MP4, WebM, or APNG. No watermark, no limitations. Good if you don't want to pay for CleanShot X.

**Other options:** Gifox (precision region selection), GIPHY Capture (simple but limited), LICEcap (lightweight, ugly UI but functional).

**Recording settings for marketing GIFs:**

| Setting | Value | Why |
|---------|-------|-----|
| Frame rate | 15 fps | Smooth enough for particle animation, cuts file size ~50% vs 30 fps |
| Duration | 10–15 seconds | Long enough to show wind gusts and variation, short enough to loop well |
| Region | Crop to relevant area | A 800×600 crop is dramatically smaller than full 2560×1600 |
| Loop | Seamless if possible | Weather effects should loop naturally — trim to a clean cycle point |

**GIF optimization (critical for platform limits):**

Use **gifski** (by ImageOptim team) for highest-quality GIF encoding. It produces noticeably better results than other encoders at the same file size.

| Platform | Max GIF size | Target size |
|----------|-------------|-------------|
| Product Hunt | 3 MB (strict) | Under 2.5 MB |
| Reddit | 100 MB (but aim low) | Under 8 MB |
| Twitter/X | 15 MB desktop, 5 MB mobile | Under 4 MB |
| Landing page | No limit, but affects load time | Under 5 MB (or use MP4 instead) |

**If you can't hit 3 MB for Product Hunt:**
- Reduce color palette from 256 to 128 colors (30–50% size reduction, slight dithering)
- Crop tighter — show just the effect, not the full desktop
- Drop to 12 fps
- Use ezgif.com for online compression with preview
- Consider using MP4 instead (85–95% smaller than GIF at same quality)

---

#### How to Record the Demo Video

**Recommended tool: OBS Studio (free) or ScreenFlow ($149)**
- OBS: Free, no watermark, unlimited recording. Steeper learning curve but unmatched flexibility.
- ScreenFlow: Native Mac, built-in video editor, captures system audio. Best for polished tutorial-style videos.
- QuickTime (built-in): Quick and dirty — good for raw footage you'll edit elsewhere.

**Recording checklist:**
1. Create a fresh macOS user account (or clean up your existing one)
2. Hide desktop icons: `defaults write com.apple.finder CreateDesktop false && killall Finder`
3. Set wallpaper to something that contrasts with weather effects (see wallpaper guide below)
4. Hide unnecessary menu bar items
5. Set system clock to 9:41 AM (Apple's convention for marketing screenshots — looks intentional)
6. Close all other apps — no notification banners interrupting your recording
7. Record at native Retina resolution (2x) for sharp output
8. Show the popover UI being used — demonstrate settings changes in real-time

**Demo video structure (60–120 seconds):**
- 0:00 — Clean desktop, app running in menu bar, snow falling
- 0:15 — Open popover, switch to rain mode (show instant transition)
- 0:30 — Adjust particle count and wind (show customization)
- 0:45 — Switch to AI storm mode (the wow moment)
- 1:00 — Pull back to show multi-display (if applicable)
- 1:15 — Quick flash of settings, close popover, end on a beautiful shot
- No voiceover needed — add text captions or let the visuals speak

---

#### How to Take Screenshots

**Recommended tool: CleanShot X or Shottr (free)**
Both offer window capture with automatic drop shadows, transparent backgrounds, and a "Backdrop" tool that adds professional gradient backgrounds + rounded corners + padding.

**Screenshot workflow:**
1. Set up the weather effect you want to capture
2. Capture the full window or region: `Cmd+Shift+4` (native) or CleanShot X hotkey
3. Use CleanShot X's "Background" tool or Shottr's "Backdrop" to add a gradient background + shadow + rounded corners
4. Export as PNG (lossless) for landing page, WebP for faster web loading

**What to capture (6 shots minimum):**

| Shot | Description | Use |
|------|-------------|-----|
| Snow hero | Full desktop with gentle snow on a dark wallpaper | Landing page hero, PH gallery |
| Rain mood | Rain streaks with splashes on a moody wallpaper | Landing page demo section |
| AI storm | Full glitch effects on a clean desktop | Landing page demo section, Twitter |
| Multi-display | Weather spanning 2–3 monitors | Landing page, shows premium feel |
| Popover UI | Menu bar popover with settings visible | PH gallery, Reddit post |
| Before/after | Clean desktop → same desktop with weather | Landing page, shows the product's value |

---

#### Device Mockups

Put your screenshots inside MacBook/iMac/Studio Display frames for the landing page hero and Product Hunt gallery. Bare screenshots look amateur; framed ones look professional.

**Tools:**
- **Rotato ($49)** — Best for 3D angled mockups. Drag in your screenshot, pick a device, adjust angle and lighting. Exports high-res PNG.
- **shots.so (free)** — Browser-based, quick device frames with customizable backgrounds.
- **MockUPhone (free)** — Simple device framing, supports MacBook and iMac.
- **Figma templates** — Search "MacBook mockup" in Figma Community for free templates you can customize.

**For wthrr:** A 3/4 angle MacBook Pro with snow falling across the screen, on a dark gradient background, is your landing page hero image.

---

#### Wallpaper Strategy (Important for a Transparent Overlay App)

The wallpaper behind your weather effects is part of the marketing. Choose deliberately.

**Best wallpapers for each mode:**

| Mode | Wallpaper | Why |
|------|-----------|-----|
| Snow | Dark navy, deep forest, or night cityscape | White particles pop against dark backgrounds |
| Rain | Moody gray gradient or overcast sky photo | Matches the rain vibe, streaks are visible |
| AI storm | Solid black or very dark gradient | Neon glitch effects are most dramatic on dark backgrounds |
| Multi-display hero shot | macOS default Sequoia wallpaper | Familiar to Mac users, shows the app in context |

**Wallpapers to avoid:**
- Busy patterns or photos with lots of detail — compete with particle effects
- Very bright/white backgrounds — snow becomes invisible
- Default macOS light wallpapers — low contrast with most effects

**Pro tip:** Use a different wallpaper for each mode's GIF/screenshot. This makes your gallery look varied and shows the effects work in different contexts.

---

#### Platform-Specific Asset Versions

You'll need different versions of the same content optimized for each platform:

| Asset | Product Hunt | Reddit | Twitter/X | Landing Page |
|-------|-------------|--------|-----------|-------------|
| Hero GIF | Under 3 MB, square or 16:9 | Under 8 MB, any ratio | Under 4 MB, 16:9 | MP4 preferred (autoplay) |
| Screenshots | 1270×760 gallery images | Inline in post body | 1600×900 for cards | 2x Retina, PNG or WebP |
| Demo video | Link to YouTube | Link to YouTube | Upload native (under 2:20) | Embedded or YouTube |
| Mockups | Not needed (raw screenshots better) | Not needed | Great for pinned tweet | Hero section, above the fold |

**When to use MP4 instead of GIF:**
- Landing page hero — MP4 is 85–95% smaller, autoplay + loop works in all browsers
- A 5-second 1280×720 clip: ~2.3 MB as GIF vs ~370 KB as MP4
- Twitter supports native video with autoplay — looks better than GIF
- Use GIF only where the platform requires it (some Reddit clients, email)

---

#### Capture Workflow (Step by Step)

**One afternoon, do this:**

1. **Set up a clean recording environment**
   - Fresh user account or hide desktop icons
   - Pick your wallpapers (one per mode — dark for snow, moody for rain, black for AI storm)
   - Hide menu bar clutter, set clock to 9:41

2. **Record raw footage for each mode** (use CleanShot X or OBS)
   - 30–60 seconds of each mode running at full quality
   - Include one recording with the popover open, changing settings
   - Include one multi-display recording if you have multiple monitors

3. **Extract GIF clips** from the raw footage
   - Trim to 10–15 second loops using CleanShot X or Kap
   - Run through gifski for optimal compression
   - Create platform-specific versions (tight crop for PH's 3 MB limit, wider for Reddit)

4. **Take static screenshots** during the session
   - Pause at the best-looking moments and capture with CleanShot X
   - Apply Backdrop tool (gradient background + shadow + rounded corners)

5. **Create device mockups** from your best screenshots
   - Drop into Rotato or shots.so
   - Export hero images for landing page

6. **Compress everything**
   - GIFs through gifski or ezgif.com
   - PNGs through ImageOptim
   - Videos through HandBrake (free) for web-optimized MP4

**Total time:** 2–4 hours for a full set of marketing assets that covers every channel.

#### Start Building in Public on Twitter/X
- Post 3–5 times per week about development progress
- Share short clips: "Added wind physics today" / "AI storm mode is getting weird (in a good way)"
- Use hashtags: #buildinpublic #indiedev #macOS #swiftui
- Engage with indie Mac dev community (Sindre Sorhus, Raycast team, Shottr dev)
- Goal: 200–500 followers by launch day who are primed and excited

#### Join Product Hunt Early
- Create your Product Hunt account 6–8 weeks before launch
- Become an active community member: upvote and comment on other Mac apps
- PH's algorithm favors engaged community members, not drive-by launchers
- Set up your product's "Coming Soon" page to collect followers

#### Build an Email Waitlist
- Add email capture to landing page: "Get notified when wthrr launches"
- Target: 200–500 signups before launch
- These people will be your Day 1 upvoters and buyers

---

### Phase 2: Launch Week (The Big Push)

Execute these in sequence over 3–5 days for maximum compounding effect.

#### Day 1: Product Hunt Launch

**Timing:** Launch Saturday or Sunday at 12:01 AM PST. Weekends have fewer competing products — you need ~366 upvotes to hit #1 on Saturday vs ~633 on Monday.

**Listing must include:**
- Animated GIF as the hero media (not a static screenshot)
- Clear one-line tagline: "Animated weather overlays for your Mac desktop"
- Detailed description explaining all three modes, multi-display, customization
- Link to YouTube demo video
- "Maker" comment explaining why you built it (personal story converts)

**Launch day actions:**
- Email your waitlist: "We're live on Product Hunt!"
- Post to Twitter: tag @ProductHunt, share your listing link
- Respond to every Product Hunt comment within the first 2 hours (critical for algorithm)
- DM friends/fellow indie devs to check it out (don't ask for upvotes explicitly — PH detects and penalizes this)

**Realistic outcome:** A well-executed PH launch for a visual Mac utility can hit 300–1,000 upvotes, Top 5 of the day, and drive 2,000–5,000 visitors to your landing page.

#### Day 2: Reddit Launch

**Primary subreddits:**
- **r/macapps** (300K+ members) — the single best subreddit for Mac utility launches
- **r/macOS** (400K+) — broader audience, good for cross-posting a day later

**Post format that works:**
- Title: "I made a free menu bar app that adds animated snow, rain, and AI storms to your Mac desktop"
- Body: 3–4 GIFs showing each mode, bullet points of features, link to download, transparent about pricing
- Tone: first-person, authentic, "I built this because..." not "Introducing the revolutionary..."

**What gets traction vs removed:**
- ✅ "I made..." / "I built..." / "After 6 months of work..."
- ❌ Marketing language, superlatives, "game-changing"
- ✅ Engaging with every comment, answering questions, taking feature requests
- ❌ Posting to 5+ subreddits on the same day (looks spammy)

**Additional subreddits (stagger over the following week):**
- r/sideproject — indie dev audience, good for the build story
- r/indiehackers — fellow developers, potential for cross-promotion
- r/unixporn or r/desktops — if your weather effects look stunning on custom setups

**Realistic outcome:** A good r/macapps post can drive 40–200+ sales directly. One indie dev reported $5,000 in a week from Reddit alone.

#### Day 3: Hacker News (Show HN)

**Post title:** "Show HN: Animated weather overlays for macOS desktops"

**What makes Show HN succeed for Mac utilities:**
- Direct, factual language (no marketing speak — HN readers smell it instantly)
- Mention the technical stack: SwiftUI, Metal/Canvas rendering, display-synced physics
- Make the app trivially easy to try (free trial, no signup, just download the DMG)
- Be prepared for technical questions about performance, CPU usage, multi-display handling

**Realistic outcome:** A front-page Show HN can drive 5,000–15,000 visitors in 24 hours. Not every post makes the front page — but visual/novel apps have an advantage.

#### Day 4–5: Follow-Up Content

- Post a "Launch recap" thread on Twitter (numbers, lessons, what surprised you)
- Thank Product Hunt and Reddit communities
- Share any fun screenshots or user reactions

---

### Phase 3: Press & Directories (Weeks 2–4)

#### Mac Blog Outreach

Email these sites with a short pitch + GIF + download link:

| Site | Why | How to Pitch |
|------|-----|--------------|
| **MacStories** | Most influential indie Mac reviewer | Email Federico/John, lead with the visual angle + technical craft |
| **9to5Mac** | Broad Apple audience | "New indie Mac utility" angle, include PH ranking |
| **MacWorld** | Software reviews section | Straightforward review request |
| **The Sweet Setup** | Curated Mac app recommendations | Focus on the "delightful utility" angle |
| **Club MacStories** | Newsletter for Mac enthusiasts | Mention if you got PH traction |

**Pitch template:**
> Subject: wthrr — animated weather overlays for macOS (just launched)
>
> Hi [name],
>
> I just launched wthrr, a menu bar app that renders animated snow, rain, and AI storm effects across all connected Mac displays. It hit [#X on Product Hunt / X upvotes on Reddit] this week.
>
> [Embedded GIF or link to 30-sec demo]
>
> It's $4.99 one-time, no subscription, no data collection. Free 14-day trial.
>
> Happy to share a complimentary license if you'd like to try it.
>
> [Your name]

**Realistic outcome:** MacStories coverage alone can drive 2,000–5,000 visits. Most cold pitches go unanswered — follow up once after a week, then move on.

#### Directory Listings (Free, Long-Tail Value)

Submit to these — they're free and generate organic traffic over time:

- **AlternativeTo.net** — add wthrr as an alternative to other weather/overlay apps
- **MacMenuBar.com** — specialized directory of 1,300+ menu bar apps
- **awesome-macos** (GitHub) — submit a PR to phmullins/awesome-macos and jaywcjlove/awesome-mac
- **Product Hunt** collection pages — add to relevant collections (menu bar apps, macOS utilities)

---

### Phase 4: Ongoing Growth (Month 2+)

#### Seasonal Marketing (Big Advantage for a Weather App)

wthrr has a natural seasonal hook that most apps don't:

| Season | Campaign | Channel |
|--------|----------|---------|
| **November** | "Snow season is here" — launch/relaunch push | Twitter, Reddit |
| **December** | "Holiday desktop vibes" — gift-giving angle | Twitter, email to existing users to gift licenses |
| **Spring** | "Rain mode for April showers" | Quick Reddit post, Twitter clip |
| **Summer** | AI Storm mode push — "When it's too hot for real weather" | Fun angle for Twitter/Reddit |

#### Version Updates as Marketing Events

Each meaningful update is a reason to post again:

- v1.1: Bug fixes (don't market this)
- v1.2: New particle effects or mode → short Reddit post + Twitter thread
- v1.5: Major feature (new weather mode? seasonal themes?) → mini Product Hunt launch + Reddit
- v2.0: If big enough → full re-launch cycle (PH, Reddit, HN, press)

#### SEO (Slow but Compounding)

- Target long-tail keywords on your landing page: "animated weather Mac," "snow effect macOS," "rain overlay Mac desktop"
- Write 2–3 blog posts on your site: "How I Built Multi-Display Weather Physics in SwiftUI," "Best Menu Bar Apps for macOS 2026"
- Technical blog posts get linked from HN and dev communities → backlinks → SEO value
- Over 6–12 months, organic search can become your largest traffic source

#### Community Building (Optional, Low-Effort)

- Create r/wthrr for users to share screenshots of their setups with weather effects
- Accept feature requests publicly (GitHub Issues or a simple feedback form)
- Monthly email to customers: new features, seasonal themes, what's coming

---

### Launch Week Revenue Expectations

| Scenario | PH + Reddit + HN Traffic | Landing Page Conversion | Sales | Revenue |
|----------|--------------------------|------------------------|-------|---------|
| Conservative | 3,000 visitors | 3% trial, 30% convert | ~27 | ~$115 |
| Moderate | 8,000 visitors | 5% trial, 40% convert | ~160 | ~$678 |
| Strong (PH #1 + Reddit viral) | 20,000 visitors | 7% trial, 40% convert | ~560 | ~$2,375 |

These are launch week only. Long-tail from directories, SEO, and word of mouth adds up over months.

---

### 90-Day Launch Calendar

| Week | Action |
|------|--------|
| 1–2 | Landing page live, GIF/video assets created, LemonSqueezy product configured |
| 3–4 | Start Twitter build-in-public posts, join Product Hunt community |
| 5–6 | YouTube demo video published, email waitlist collecting signups |
| 7–8 | Product Hunt "Coming Soon" page live, pitch drafted for Mac blogs |
| 9–10 | Email MacStories, Macworld, Sweet Setup (give them early access + license) |
| 11 | Final polish, prep Reddit post drafts, line up PH launch |
| **12** | **LAUNCH WEEK: PH Saturday → Reddit Monday → HN Tuesday → Twitter daily** |
| 13–14 | Follow up with press, submit to directories, post launch recap |
| 15–16 | v1.1 bug fix release, collect testimonials, update landing page with social proof |

---

### What Makes wthrr Marketable

Most indie Mac utilities struggle to create visual marketing content. wthrr doesn't have this problem:

- **Every screenshot is a demo** — weather effects on a real desktop look interesting
- **GIFs sell themselves** — 3 seconds of animated snow is more compelling than any copy
- **Three distinct modes** — snow, rain, AI storm give you three different visual hooks
- **Multi-display is impressive** — screenshots of weather spanning 2–3 monitors look premium
- **Seasonal relevance** — you can re-market the same app every winter

The marketing strategy is simple: **make it look cool, put it where Mac users hang out, and let the visuals do the selling.**

---

## Summary

| Component | Solution | Cost |
|-----------|----------|------|
| Source + releases | Public GitHub repo (`todddube/wthrr_mac`) | $0 |
| Sales landing page | thedubes.com/wthrr (GitHub Pages + custom domain) | $0 |
| Payment + license keys | LemonSqueezy | ~$0.75/sale (~$4.24 net) |
| Trial model | 14-day full trial → 10-min sessions | $0 |
| License storage | macOS Keychain | $0 |
| Code signing + notarization | Apple Developer ID | $99/year |
| Auto-updates | Sparkle framework (appcast on GitHub Releases) | $0 |
| New app code | ~300 lines Swift (LicenseManager + UI) | ~2–3 days |
| Ongoing maintenance | Near zero | — |
| **Total upfront** | | **$99/year + 2–3 days dev** |
