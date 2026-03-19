# wthrr Monetization Spec

## Price: $4.99 one-time license — direct sales, no App Store

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

## Trial Strategy Options

### Option A: 14-Day Full Trial (Recommended)

**How it works:**
- Download is free. All features work for **14 days** — snow, rain, AI storm, all displays, full customization.
- On day 10, a subtle banner appears in the popover: *"Trial ends in 4 days — get wthrr for $4.99"*
- On day 15, overlays stop rendering. The popover shows a clean purchase/activate screen.
- A "Preview" button lets users see a **30-second demo** of the effects after trial expiry (keeps the hook alive).

**Why 14 days:**
- Industry data shows 14-day trials convert 2–3× better than immediate paywalls
- Users build the habit of seeing weather on their desktop — it becomes part of their setup
- Shottr and Bartender both use multi-week trials and convert well at higher price points
- 14 days is long enough to experience seasonal weather changes and different modes

**After trial expires:**
- Popover opens normally, shows settings (read-only) + purchase prompt
- Overlays don't render (clean stop, no frozen particles)
- "Preview for 30 seconds" button gives a taste to re-motivate purchase
- "Activate License" field + "Buy License ($4.99)" button

**Implementation:**
- `LicenseManager` stores `trialStartDate` in Keychain (tamper-resistant)
- On each launch: `if daysSince(trialStartDate) > 14 && !isLicensed → expired`
- No server call needed for trial logic — purely local

### Option B: 2-Minute Per-Session Trial (Original Spec)

**How it works:**
- All features work for **2 minutes** per launch, then animation pauses
- "Restart Preview" button gives another 2 minutes (unlimited restarts)
- Purchase prompt appears when timer expires

**Pros:**
- Zero infrastructure (no persistent date tracking needed)
- Users can keep restarting — low friction, mild annoyance drives purchase
- Simpler to implement

**Cons:**
- 2 minutes may not be enough to appreciate the effects
- Frequent interruptions can feel hostile rather than motivating
- Users may just never bother buying because the restart loop is "good enough"

### Option C: Feature-Limited Free Tier + Paid Unlock

**How it works:**
- **Free forever:** Snow mode only, single display, default settings
- **Paid ($4.99):** Unlocks rain, AI storm, multi-display, full particle/wind/speed controls

**What's free vs paid:**

| Feature | Free | Licensed |
|---------|------|----------|
| Snow overlay | ✅ | ✅ |
| Rain overlay | ❌ | ✅ |
| AI Storm overlay | ❌ | ✅ |
| Multi-display | ❌ (primary only) | ✅ |
| Particle count slider | Limited (1–50) | Full (1–300) |
| Wind control | ❌ (default wind) | ✅ |
| Speed control | ❌ (default speed) | ✅ |

**Pros:**
- Free tier has genuine value — snow on one screen is still cool
- No timer pressure — users upgrade when they want more
- Locked features visible in UI create natural "upgrade moments"
- Word of mouth: free users tell friends, some convert

**Cons:**
- More complex code (feature flags throughout settings and renderers)
- Risk of free tier being "enough" for casual users
- Harder to showcase rain and AI storm modes if users never see them

**Hybrid possibility:** Free tier + 3-day "Premium Preview" where all features are unlocked so users can see what they're missing, then reverts to free tier.

### Recommendation: Option A (14-Day Trial)

The full experience IS the product. Feature-gating snow vs. rain vs. AI storm fragments the value proposition. A generous trial lets users fall in love with the complete experience, then pays for itself through higher conversion.

However, **Option C (Feature-Limited)** is worth considering if you want organic word-of-mouth growth — free users are free marketing.

---

## License Key Platform

### LemonSqueezy (Recommended)

**Why LemonSqueezy over Gumroad:**
- **Lower fees:** 5% + $0.50 per transaction (vs Gumroad's ~10%)
- On a $4.99 sale: LemonSqueezy takes ~$0.75, Gumroad takes ~$0.50. Close enough — but LemonSqueezy's tooling is better.
- **Purpose-built license key system:** Each purchase auto-generates a license key with configurable activation limits
- **API for validation:** Simple REST endpoint to verify keys
- **Merchant of record:** Handles global sales tax, EU VAT — you don't deal with tax compliance
- **Modern dashboard:** Better UX than Gumroad for managing products, keys, customers
- **No approval process:** Sign up and start selling immediately

**How it works:**
1. Create LemonSqueezy account → create product "wthrr" at $4.99
2. Configure license key settings: max 3 activations per key (covers multiple Macs)
3. Customer buys → gets license key via email automatically
4. In the app, user enters key → app calls LemonSqueezy API to validate
5. On success, store key in Keychain → app unlocked permanently

**API call:**
```
POST https://api.lemonsqueezy.com/v1/licenses/validate
Body: { "license_key": "<user_key>", "instance_name": "<machine_id>" }
```

**Revenue per sale:**
- Price: $4.99
- LemonSqueezy fee: ~$0.75
- **You keep: ~$4.24**

### Alternative: Gumroad

Same basic model. Slightly higher fees but simpler API. Good fallback if LemonSqueezy doesn't feel right.

**API call:**
```
POST https://api.gumroad.com/v2/licenses/verify
Body: product_id=<id>&license_key=<key>
```

### Alternative: Paddle

More polished, has a native macOS SDK that handles the entire activation UI for you. Popular with higher-priced Mac apps. Overkill for a $5 utility but worth knowing about.

### Alternative: DIY with Stripe

Full control, lowest fees (2.9% + $0.30), but you build and maintain everything: payment page, license key generation, email delivery, validation endpoint. Only worth it if you plan to sell multiple products.

### Platform Comparison

| | LemonSqueezy | Gumroad | Paddle | DIY + Stripe |
|---|---|---|---|---|
| Fee on $4.99 sale | ~$0.75 | ~$0.50 | ~$0.75 | ~$0.44 |
| License key generation | ✅ Auto | ✅ Auto | ✅ Auto | 🔧 Build it |
| License validation API | ✅ | ✅ | ✅ SDK | 🔧 Build it |
| Tax compliance | ✅ | ✅ | ✅ | ❌ You handle |
| Activation limits | ✅ Built-in | ⚠️ Basic | ✅ | 🔧 Build it |
| Setup time | 1 hour | 1 hour | 2–3 hours | 1–2 days |
| Infrastructure to maintain | None | None | None | Server + email |

---

## Implementation Plan

### Phase 1: LicenseManager (~1 day)

```
LicenseManager.swift
├── LicenseState enum: .trial(daysRemaining) / .trialExpired / .licensed
├── trialStartDate: Date? (stored in Keychain)
├── storedLicenseKey: String? (stored in Keychain)
├── isLicensed: Bool (computed)
├── trialDaysRemaining: Int (computed)
├── startTrialIfNeeded() — sets trialStartDate on first launch
├── validate(key:) async -> Result<Void, LicenseError>
│   └── calls LemonSqueezy API, stores key on success
├── checkStatus() -> LicenseState
└── deactivate() — for testing/support
```

**Keychain storage** (not UserDefaults) because:
- Harder to tamper with than plist files
- Survives app reinstalls (persists across updates)
- Encrypted at rest by macOS

### Phase 2: Trial Logic (~0.5 day)

In `WeatherAnimationModel.advance()`:
```swift
guard LicenseManager.shared.state != .trialExpired else { return }
```

Trial countdown:
- `trialStartDate` set on first launch
- Each launch computes `Calendar.current.dateComponents([.day], from: trialStartDate, to: .now).day`
- Days 1–9: No UI indication (let them enjoy it)
- Days 10–14: Subtle banner in popover footer
- Day 15+: Overlays stop, purchase screen shown

### Phase 3: License Prompt UI (~0.5 day)

**During trial (days 10–14) — soft nudge:**
- Small text in popover footer: "Trial: 4 days remaining · Buy wthrr"
- Non-intrusive, no modals, no blocking

**After trial — purchase screen in popover:**
- "Your 14-day preview has ended"
- TextField for license key + "Activate" button
- "Buy License ($4.99)" button → opens LemonSqueezy product page
- "Preview for 30 seconds" button → runs full effects briefly
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

## Decision Matrix: Which Trial Model?

| Factor | 14-Day Trial (A) | 2-Min Session (B) | Feature-Limited (C) |
|--------|------------------|--------------------|---------------------|
| Conversion rate | ⭐⭐⭐ Highest | ⭐⭐ Medium | ⭐ Lowest |
| Implementation complexity | Medium | Low | High |
| User experience | Best (no interruptions) | Worst (constant pauses) | Good (but limited) |
| Word of mouth potential | Medium | Low | ⭐⭐⭐ Highest (free users share) |
| Code changes needed | ~300 lines | ~200 lines | ~500+ lines (feature flags) |
| Risk of "good enough" free tier | None (expires) | Low (restart loop) | High (snow-only may suffice) |

**Bottom line:** Start with Option A (14-day trial). If you later want organic growth, add a free tier (Option C) as v2 — the license infrastructure is the same either way.

---

## Summary

| Component | Solution | Cost |
|-----------|----------|------|
| Payment + license keys | LemonSqueezy | ~$0.75/sale |
| Trial model | 14-day full-feature trial | $0 |
| License storage | macOS Keychain | $0 |
| Code signing + notarization | Apple Developer ID | $99/year |
| Auto-updates | Sparkle framework | $0 |
| Landing page | GitHub Pages / Netlify | $0 |
| New app code | ~300 lines Swift | ~2–3 days |
| Ongoing maintenance | Near zero | — |
