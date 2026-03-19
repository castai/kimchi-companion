# Kimchi Companion — Project Plan

**macOS Menu Bar Usage Tracker for AI Enabler**
*Inspired by CodexBar · Powered by the Kimchi Analytics API*

---

## 1. Vision

Kimchi Companion is a lightweight macOS menu bar app that gives every AI Enabler user instant, glanceable visibility into their personal and team AI consumption — without opening a browser. One icon in the toolbar. Click it, see your usage. That's it.

Think of it as **CodexBar, but for CAST AI's AI Enabler**. Where CodexBar tracks quotas across third-party providers by scraping cookies and local logs, Kimchi Companion talks directly to the Kimchi Analytics API (`AnalyticsAPI_GenerateAnalytics`) to pull real usage data — cost, tokens, requests — scoped to your API key, your team, your org.

---

## 2. Why Build This

AI Enabler already tracks usage per user, per team, per project through the console's Analytics dashboard. But engineers live in their terminal, not the browser. The internal docs say it clearly: *"AI Engineers prefer simple inference endpoints and Python SDKs"* — they don't want to context-switch into a web console to check how much they've burned through today.

**The gap:** There is no lightweight, always-on usage indicator that lives where engineers work.

**The opportunity:** A menu bar companion app would:

- Give individual engineers real-time awareness of their own consumption (tokens, cost, requests)
- Surface team-level usage for leads who need chargeback visibility
- Reinforce CAST AI's "per-engineer governance and cost visibility" positioning
- Create a touchpoint outside the browser — a small PLG surface that keeps AI Enabler top-of-mind
- Complement the standalone AI Enabler UI (`inference.cast.ai`) being built out

---

## 3. Inspiration: What CodexBar Does Right

CodexBar (by Peter Steinberger, MIT-licensed, [github.com/steipete/CodexBar](https://github.com/steipete/CodexBar)) is the gold standard for this pattern. Key design decisions to borrow:

| CodexBar Pattern | Kimchi Companion Adaptation |
|---|---|
| **Tiny dual-bar meter icon** — session usage (top) + weekly (bottom) in the menu bar itself | **Single bar or percentage fill** showing daily/weekly spend against budget or historical baseline |
| **No Dock icon** — minimal, lives only in the menu bar | Same. Pure menu bar app, no Dock presence |
| **Click to expand** — shows per-provider cards with reset countdowns | Click shows a popover with personal usage, team usage, cost breakdown by model |
| **Privacy-first** — reads local data, never phones home | We call the Kimchi API, but only with the user's own API key. No telemetry beyond what AI Enabler already collects |
| **Homebrew install** — `brew install --cask steipete/tap/codexbar` | `brew install --cask castai/tap/kimchi-companion` |
| **Configurable refresh** — 1m, 2m, 5m, 15m | Same cadence options. Default 5m to be gentle on the API |
| **Merge mode** — combines multiple providers into one icon | Not needed initially (single provider), but could support multiple orgs later |
| **CLI companion** — `codexbar cost --provider codex` | Future: `kimchi usage --period today --format json` for CI/scripts |

---

## 4. Architecture

### 4.1 Tech Stack

| Component | Choice | Rationale |
|---|---|---|
| Language | **Swift** | Native macOS, best menu bar integration, small binary, no runtime dependencies |
| UI Framework | **SwiftUI** | Modern declarative UI for popover, settings. Supports macOS 14+ |
| Networking | **URLSession** | Native, no deps needed for REST API calls |
| Distribution | **Homebrew Cask** | Standard for macOS dev tools. Also GitHub Releases + Sparkle auto-update |
| Keychain | **Security.framework** | Store API key securely in macOS Keychain |
| Min OS | **macOS 14 (Sonoma)** | Matches CodexBar. Covers most dev machines |

### 4.2 Data Flow

```
┌─────────────────┐      HTTPS/REST       ┌──────────────────────┐
│                  │ ───────────────────►   │                      │
│  Kimchi Companion│   API Key in header    │  Kimchi Analytics API │
│  (menu bar app)  │ ◄───────────────────   │  (cast.ai backend)   │
│                  │   JSON response        │                      │
└─────────────────┘                        └──────────────────────┘
        │
        ▼
┌─────────────────┐
│  macOS Keychain  │  ← API key stored here
└─────────────────┘
```

### 4.3 API Integration

**Primary endpoint:** `POST /v1/ai-optimizer/analytics/generate`
(documented at `docs.cast.ai/reference/analyticsapi_generateanalytics`)

The app will call this endpoint with the user's CAST AI API key to fetch:

- **Personal usage:** Filter by the user's own API key to get tokens consumed, cost, request count
- **Team usage:** If the user has org-level permissions, fetch aggregated team data
- **Model breakdown:** Which models are consuming the most (e.g., `glm-5-fp8` vs `minimax-m2.5`)
- **Time periods:** Today, this week, this month, with reset countdowns

**Authentication:** Bearer token using the user's CAST AI API key (same key used for `llm.cast.ai/openai/v1` inference calls).

**Fallback:** If the analytics endpoint is unavailable or rate-limited, show the last cached data with a "stale" indicator (icon dims, like CodexBar does).

---

## 5. User Experience

### 5.1 First Launch

1. User installs via `brew install --cask castai/tap/kimchi-companion`
2. App opens with a setup popover: "Paste your CAST AI API key"
3. Key is validated with a test call to the analytics endpoint
4. On success: icon appears in menu bar showing today's usage. Setup dismissed.
5. On failure: clear error message ("Invalid key" / "No permissions" / "Network error")

### 5.2 Menu Bar Icon States

```
Normal:        ◉  (small filled circle with usage percentage)
Low usage:     ◉  (green tint — under 50% of daily average)
Medium usage:  ◉  (amber tint — 50-80%)
High usage:    ◉  (red tint — over 80% or approaching budget)
Stale data:    ◎  (dimmed — last refresh failed)
Loading:       ⟳  (subtle animation on refresh)
```

The icon can optionally show a compact number (e.g., `$4.2` or `12K tok`) next to it — configurable in settings.

### 5.3 Click → Popover

When the user clicks the icon, a clean popover appears:

```
┌──────────────────────────────────┐
│  🔥 Kimchi Companion             │
│  ─────────────────────────────── │
│                                  │
│  YOUR USAGE TODAY                │
│  ████████░░░░░░  $3.42           │
│  12,847 tokens · 23 requests     │
│  Resets in 6h 12m                │
│                                  │
│  THIS WEEK                       │
│  ██████░░░░░░░░  $18.90          │
│  68,421 tokens · 142 requests    │
│                                  │
│  ─────────────────────────────── │
│  TOP MODELS                      │
│  glm-5-fp8        $14.20  (75%) │
│  minimax-m2.5      $4.70  (25%) │
│                                  │
│  ─────────────────────────────── │
│  TEAM (Engineering)              │
│  $142.30 this week · 12 members  │
│  Your share: 13%                 │
│                                  │
│  ⚙ Settings    ↗ Open Dashboard  │
└──────────────────────────────────┘
```

Design principles: dark theme by default (matches dev tooling), minimal chrome, monospace numbers for alignment, color-coded progress bars.

### 5.4 Settings

- API Key management (change/remove, stored in Keychain)
- Refresh interval (1m / 2m / 5m / 15m / manual)
- Show in menu bar: icon only / icon + cost / icon + tokens
- Budget alert threshold (optional — show notification when daily spend exceeds $X)
- Launch at login toggle
- Team view on/off

---

## 6. Phased Delivery

### Phase 1: MVP (4-6 weeks)

**Goal:** Working menu bar app that shows personal usage.

| Deliverable | Details |
|---|---|
| Menu bar icon | Static icon with color coding based on usage level |
| API key setup | First-launch flow, Keychain storage, validation |
| Personal usage popover | Today + this week: cost, tokens, requests |
| Model breakdown | Top models by cost |
| Auto-refresh | Configurable polling interval |
| Homebrew distribution | `castai/tap` Homebrew tap with cask formula |
| GitHub Releases | Signed .dmg for manual install |

**Not in MVP:** Team view, CLI tool, notifications, widgets.

### Phase 2: Team & Polish (3-4 weeks)

| Deliverable | Details |
|---|---|
| Team usage view | Aggregated team data in popover (if permissions allow) |
| Budget alerts | macOS notifications when thresholds are exceeded |
| Sparkle auto-update | Silent background updates |
| "Open Dashboard" link | Deep-link to `inference.cast.ai` analytics page |
| Keyboard shortcut | Global hotkey to toggle popover |

### Phase 3: Power Features (4+ weeks)

| Deliverable | Details |
|---|---|
| CLI companion | `kimchi usage` command for terminal/CI |
| WidgetKit widget | macOS desktop widget mirroring popover data |
| Multi-org support | Switch between CAST AI orgs |
| Historical trends | Sparkline charts showing usage over past 7/30 days |
| Cost anomaly detection | Alert when usage pattern deviates significantly |

---

## 7. Technical Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Analytics API rate limits | App polls too frequently for many users | Default 5m refresh, respect rate-limit headers, exponential backoff |
| API key scope | User's key may not have analytics permissions | Validate on setup, show clear error if insufficient permissions |
| API response format changes | Breaking changes to the analytics endpoint | Version-pin expected schema, graceful degradation on unknown fields |
| macOS sandboxing | App Store distribution requires sandbox | Distribute via Homebrew/GitHub first (no sandbox). App Store is a later option |
| Team data access | Not all keys may have team-level visibility | Gracefully hide team section if API returns 403 |
| Competing with console | Internal pushback ("just use the dashboard") | Position as complementary — the app drives engagement back to the console |

---

## 8. Distribution Strategy

### Homebrew (Primary)

```bash
brew tap castai/tap
brew install --cask kimchi-companion
```

This is the standard for macOS developer tools. Create a Homebrew tap repository at `github.com/castai/homebrew-tap` with the cask formula.

### GitHub Releases

Universal binary (Apple Silicon + Intel) as a signed `.dmg`. Sparkle framework for auto-updates checking GitHub releases.

### Internal Dogfood

Distribute internally first via the CAST AI org. Every engineer using AI Enabler for coding (OpenCode, Claude Code, GSD) should have it installed — they're the perfect initial users and feedback loop.

---

## 9. Success Metrics

| Metric | Target (3 months post-launch) |
|---|---|
| Internal adoption | 80%+ of CAST AI engineers using AI Enabler have it installed |
| External installs | 500+ Homebrew installs |
| Daily active users | 60%+ of installers open the popover at least once per day |
| Dashboard click-through | 15%+ of popover opens result in "Open Dashboard" click |
| Retention | 70%+ still active after 30 days |

---

## 10. Open Questions

1. **API endpoint confirmation:** The `AnalyticsAPI_GenerateAnalytics` endpoint needs validation — what exact filters, dimensions, and metrics does it support? Can it filter by individual API key? What's the rate limit?

2. **"Kimchi" branding:** Is "Kimchi" the confirmed public-facing name for the AI Enabler product, or is it an internal codename? The app name should align with whatever branding ships externally.

3. **Open source?** CodexBar is MIT-licensed and has strong community engagement. Should Kimchi Companion follow the same model for developer trust and contributions?

4. **Standalone vs. bundled:** Should this ship as a standalone app, or should it be part of a future CAST AI CLI/developer toolkit?

5. **Team permissions model:** What org-level permissions are needed to see team-aggregated data vs. personal-only data? This affects the UI flow.

6. **Budget/quota concept:** Does AI Enabler have per-user budgets or quotas today? If not, the "percentage" visualization needs a different baseline (e.g., rolling average).

---

## 11. References

- **CodexBar:** [codexbar.app](https://codexbar.app/) · [GitHub](https://github.com/steipete/CodexBar) — MIT-licensed macOS menu bar AI usage tracker by Peter Steinberger
- **AI Enabler API:** [docs.cast.ai/reference/analyticsapi_generateanalytics](https://docs.cast.ai/reference/analyticsapi_generateanalytics) — Analytics endpoint
- **AI Enabler Base URL:** `https://llm.cast.ai/openai/v1` — Inference endpoint (OpenAI-compatible)
- **AI Enabler Standalone:** `inference.cast.ai` — Upcoming standalone UI (Phase 1 in progress)
- **Internal Docs:** AI Enabler Cheat Sheet, Dual Model Coding Agent Guide, AI Enabler Standalone Serverless Model APIs (Confluence)
