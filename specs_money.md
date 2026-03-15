# wthrr Monetization Spec

## Model: Free Download → Time-Limited Trial → Paid License

The app is free to download and install. All features work fully for **2 minutes** per session, then the weather effect pauses and a prompt appears asking the user to enter a license key. This is a one-time purchase, not a subscription.

---

## 1. Trial Behavior

### How it works
- On launch, a 2-minute countdown timer starts (managed in `SnowflakeAnimationModel`).
- When the timer expires:
  1. The particle animation pauses (timer invalidated, particles freeze in place).
  2. A **license prompt overlay** appears on the menu bar popover (not on the weather overlay windows).
  3. The overlay shows: "Trial ended — enter your license key to unlock wthrr" with a text field and "Activate" button, plus a "Buy License" link.
  4. A "Restart Trial" button lets users get another 2 minutes (unlimited restarts — low friction, encourages purchase through mild annoyance rather than hard locks).
- If the user quits and relaunches, the 2-minute trial resets (per-session, not cumulative).

### Implementation
- Add a `LicenseState` enum: `.trial(secondsRemaining)`, `.expired`, `.licensed`
- Add `LicenseManager` class (singleton) that:
  - Stores the license key in the macOS **Keychain** (not UserDefaults — harder to tamper with)
  - Validates on launch by checking the stored key
  - Manages the countdown timer
  - Publishes state changes so the UI can react

### Why per-session (not cumulative)?
- Simpler to implement (no persistent timer state)
- More generous — users can keep restarting, which builds familiarity
- The interruption alone is enough motivation to buy

---

## 2. License Key System

### Option A: Gumroad (Recommended — Zero Infrastructure)

**Gumroad** (gumroad.com) handles everything: payment processing, license key generation, email delivery, and a validation API.

**How it works:**
1. Create a Gumroad product for wthrr (e.g., $4.99 one-time).
2. Gumroad generates a unique license key per purchase and emails it to the buyer.
3. In the app, when the user enters a key, call Gumroad's license verification API:
   ```
   POST https://api.gumroad.com/v2/licenses/verify
   Body: product_id=<your_product_id>&license_key=<user_key>
   ```
4. If the API returns `success: true`, store the key in Keychain and unlock permanently.
5. The app should also cache the validation result locally (Keychain) so it works offline after the first activation.

**Pros:**
- Zero backend infrastructure to build or maintain
- Gumroad handles payments, taxes, refunds, email receipts
- License API is simple (one HTTP POST)
- Dashboard shows sales, analytics, refund rates
- Supports discount codes, bundles, "pay what you want"

**Cons:**
- Gumroad takes ~10% fee (recently changed — check current rates)
- You depend on their API uptime for first activation
- Less control over the experience

### Option B: LemonSqueezy (Similar, Newer Alternative)

Same model as Gumroad but with a more modern API and better macOS app support. Also handles license key generation and verification via API. Worth comparing fees.

### Option C: Paddle (More Polished, Mac-Native)

Paddle is popular with Mac indie developers. It provides:
- Payment processing (acts as merchant of record — handles EU VAT, sales tax)
- License key generation and verification SDK
- A native macOS licensing SDK (`Paddle.framework`) that handles the activation UI for you
- In-app purchase prompts, trial management, receipt validation

**Pros:**
- Purpose-built for Mac apps
- Native SDK means less UI work
- Handles all tax compliance globally

**Cons:**
- Higher fees (~5-10% + per-transaction)
- More complex integration
- SDK adds a framework dependency

### Option D: DIY with Stripe + Email (More Work, Full Control)

Build a minimal backend:
1. **Stripe Checkout** — create a payment link or hosted checkout page.
2. **Stripe Webhook** — on successful payment, generate a license key (UUID or signed token) and email it to the buyer via **SendGrid**, **Postmark**, or **AWS SES**.
3. **Validation** — the app sends the key to your server (or validates a signed JWT offline).

**Infrastructure needed:**
- A small server or serverless function (Cloudflare Worker, AWS Lambda, or Vercel edge function)
- ~50 lines of code for the webhook handler
- Email service account

**Pros:**
- Full control over keys, pricing, customer data
- Lower per-transaction fees (Stripe: 2.9% + $0.30)
- Can do offline validation with signed keys (no server call needed after generation)

**Cons:**
- You build and maintain the infrastructure
- You handle tax compliance
- More moving parts

---

## 3. Recommendation: Start with Gumroad

For a solo developer with a small menu bar utility, Gumroad is the clear winner:

| Concern | Gumroad Solves It |
|---------|-------------------|
| Payment processing | Yes (Stripe-backed) |
| License key generation | Yes (automatic per sale) |
| License key delivery | Yes (emailed to buyer) |
| License verification API | Yes (one POST endpoint) |
| Tax handling | Yes (they're merchant of record) |
| Refunds | Yes (dashboard or API) |
| Analytics | Yes (sales dashboard) |
| Infrastructure to maintain | None |

**Total new code in the app: ~200-300 lines:**
- `LicenseManager.swift` — Keychain storage, Gumroad API call, state management
- `LicensePromptView.swift` — SwiftUI view with text field + buttons
- Timer logic in `SnowflakeAnimationModel` — pause after 2 min if unlicensed
- "Buy License" button opens Gumroad product page in browser

---

## 4. Implementation Plan

### Phase 1: License Manager (~1 day)

```
LicenseManager.swift
├── LicenseState enum: .trial / .expired / .licensed
├── storedKey: String? (read/write Keychain)
├── validate(key:) async -> Bool (call Gumroad API)
├── trialSecondsRemaining: Int (published)
├── startTrial() — begins 120s countdown
├── restartTrial() — resets to 120s
└── activate(key:) async -> Result<Void, LicenseError>
```

### Phase 2: Trial Timer (~0.5 day)

In `SnowflakeAnimationModel.advance()`:
```swift
// Check license state before advancing particles
guard LicenseManager.shared.state != .expired else { return }
```

Decrement `trialSecondsRemaining` each second. When it hits 0, set state to `.expired`.

### Phase 3: License Prompt UI (~0.5 day)

Add a `LicensePromptView` that appears in the menu bar popover when trial expires:
- Text: "Your 2-minute preview has ended"
- TextField for license key + "Activate" button
- "Buy License ($X.99)" button → opens Gumroad URL
- "Restart Preview" button → calls `restartTrial()`
- On successful activation: dismiss prompt, resume animation, never show again

### Phase 4: Gumroad Setup (~1 hour)

1. Create Gumroad account
2. Create product: "wthrr — Weather Effects for Mac"
3. Set price ($3.99–$5.99 sweet spot for menu bar utilities)
4. Copy product permalink (for "Buy" button) and product ID (for API verification)
5. Test with Gumroad's test mode

### Phase 5: Polish (~0.5 day)

- Show remaining trial time in popover (subtle, e.g., "Preview: 1:42 remaining")
- Offline grace: if already activated, skip API call (trust Keychain)
- Handle edge cases: no internet during activation (show error + retry), invalid key, revoked key
- Add "Licensed" badge in the About section when activated

---

## 5. Pricing Strategy

| Price Point | Rationale |
|-------------|-----------|
| **$3.99** | Impulse buy territory. Low friction. |
| **$4.99** | Sweet spot for Mac menu bar utilities. Most indie weather/utility apps land here. |
| **$5.99** | Still reasonable. Leaves room for sales/discounts. |

**Suggested: $4.99** with occasional $2.99 sales.

Consider a **"pay what you want"** minimum of $2.99 on Gumroad — some users will pay more, and it feels generous.

---

## 6. Alternatives Considered & Rejected

### Mac App Store In-App Purchase
- Apple takes 30% (15% for small business program)
- Sandboxing restrictions may interfere with overlay windows (cross-screen transparent windows need specific entitlements)
- App Review process adds friction for updates
- However: built-in payment + StoreKit handles everything natively

**Verdict:** The overlay window architecture may conflict with App Store sandboxing. Direct distribution with Gumroad avoids this entirely.

### Subscription Model
- Overkill for a decorative utility — users expect one-time purchase
- Creates ongoing obligation to deliver value
- Higher churn, more support burden

**Verdict:** One-time purchase is the right fit.

### Freemium (Free Forever + Paid Premium Features)
- Hard to gate features when the app is simple (all features are "the app")
- Time-limiting is cleaner than feature-limiting for this type of product

**Verdict:** Time-limited trial is better than feature gating here.

---

## 7. Anti-Piracy (Keep It Simple)

Don't over-invest in DRM. For a $5 app:

- **Keychain storage** makes casual tampering harder than UserDefaults
- **Server-side validation** (Gumroad API) on first activation prevents key-sharing at scale
- **Optional:** tie the key to a machine ID (hardware UUID) — Gumroad supports `increment_uses_count` to limit activations per key (e.g., 3 machines)
- **Don't:** obfuscate code, add aggressive checks, or punish paying users with friction

If someone pirates a $5 utility, they were never going to pay. Focus energy on making the purchase experience smooth.

---

## 8. Summary

| Component | Solution | Cost to You |
|-----------|----------|-------------|
| Payment processing | Gumroad | ~10% per sale |
| License key generation | Gumroad (automatic) | $0 |
| License delivery | Gumroad (email) | $0 |
| License verification | Gumroad API (1 endpoint) | $0 |
| Backend infrastructure | None needed | $0 |
| New app code | ~200-300 lines of Swift | 2-3 days of work |
| Ongoing maintenance | Near zero | — |
