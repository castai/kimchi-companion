# 🌶️ Kimchi Companion

A macOS menu bar app for monitoring your [CAST AI](https://cast.ai) LLM usage, costs, and savings — at a glance.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift 6](https://img.shields.io/badge/Swift-6-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## What it does

Kimchi Companion lives in your menu bar and gives you real-time visibility into your CAST AI inference spend without switching to a browser.

- **Live cost tracking** — see today's and this week's spend directly in the menu bar
- **Token & request counts** — input tokens, output tokens, and request volume at a glance
- **Three scope views** — Global (org-wide), Team (per-API-key breakdown), and Individual (single key detail)
- **Savings insights** — see achieved savings, potential savings, and cost comparisons from CAST AI recommendations
- **Category & model breakdowns** — understand where your spend goes by category and model
- **Background polling** — configurable refresh interval (1 min to 15 min), auto-refreshes on launch and popover open
- **Disk cache** — shows cached data instantly on launch, refreshes in the background
- **Stale data indicator** — clearly marks when displayed data might be outdated
- **Keychain storage** — your API key is stored securely in the macOS Keychain, never on disk
- **Launch at login** — optional, toggle in settings
- **Configurable display** — choose between icon only, icon + cost, or icon + token count in the menu bar

## Install

### Homebrew (recommended)

```bash
brew tap castai/homebrew-tap
brew install --cask kimchi-companion
```

### Manual download

1. Download `KimchiCompanion.dmg` from the [latest release](https://github.com/castai/kimchi-companion/releases/latest)
2. Open the DMG and drag **Kimchi Companion** to Applications
3. Launch from Applications — it appears in the menu bar

### Build from source

Requires macOS 14+ and Swift 6.

```bash
git clone https://github.com/castai/kimchi-companion.git
cd kimchi-companion
swift build -c release
```

To package a `.app` bundle and DMG:

```bash
bash scripts/package-app.sh
# Output: build/Kimchi Companion.app and build/KimchiCompanion.dmg
```

## Setup

1. Launch Kimchi Companion — a 🔥 icon appears in your menu bar
2. Click the icon to open the popover
3. Paste your CAST AI API key (get one at [kimchi.console.cast.ai](https://kimchi.console.cast.ai))
4. Click **Validate & Save** — the key is verified against the CAST AI API and stored in Keychain
5. Your usage dashboard loads immediately

## Usage

### Menu bar

The menu bar shows a flame icon with your current spend or token count (configurable in Settings). Click it to open the full dashboard.

### Dashboard views

| View | What it shows |
|------|--------------|
| **Global** | Org-wide today/week cost, tokens, requests, savings summary, category and model breakdowns |
| **Team** | Aggregated team totals plus per-API-key cost, token, and request breakdown |
| **Individual** | Pick a single API key from the dropdown to see its isolated usage |

### Settings

Access settings at the bottom of the popover:

- **Refresh interval** — 1 min, 2 min, 5 min, or 15 min polling cycle
- **Display mode** — Icon only, Icon + Cost, or Icon + Tokens in the menu bar
- **Launch at Login** — start automatically when you log in
- **Change / Remove API Key** — update or delete your stored key

## Architecture

```
Sources/
├── KimchiCompanion/            # App entry point (@main)
│   └── KimchiCompanionApp.swift
└── KimchiCompanionCore/        # Library target (all logic + UI)
    ├── AppState.swift           # @Observable state — single source of truth
    ├── UsageStore.swift         # Fetch → cache → display → stale pipeline
    ├── CastAPIClient.swift      # HTTP client for CAST AI report APIs
    ├── APIKeyValidator.swift    # Lightweight key validation probe
    ├── KeychainManager.swift    # macOS Keychain CRUD wrapper
    ├── PreferencesStore.swift   # UserDefaults-backed settings
    ├── UsageData.swift          # Codable models for all API responses + cache
    ├── PopoverContentView.swift # Root popover with scope picker + dashboard
    ├── SetupView.swift          # First-launch API key entry
    ├── SettingsView.swift       # Inline settings section
    ├── UsageView.swift          # Reusable cost/token/request display
    ├── SavingsView.swift        # Savings summary banner
    ├── ModelBreakdownView.swift # Per-model cost breakdown
    ├── CategoryBreakdownView.swift # Per-category cost breakdown
    ├── KeyBreakdownView.swift   # Per-API-key usage breakdown
    ├── MenuBarLabel.swift       # Menu bar icon + text
    └── PepperIcon.swift         # Custom pepper icon asset
```

**Key design choices:**

- All non-`@main` code lives in `KimchiCompanionCore` for testability
- `AppState` uses `@Observable` + `@Environment` for SwiftUI integration
- `UsageStore` orchestrates concurrent API calls, merges responses, writes disk cache, and tracks staleness
- API key is never logged or included in error messages
- `LSUIElement = true` — the app doesn't appear in the Dock or Cmd+Tab switcher

## API endpoints

Kimchi Companion calls these CAST AI endpoints using the `X-API-Key` header:

| Endpoint | Purpose |
|----------|---------|
| `GET /v1/llm/openai/supported-providers` | API key validation |
| `GET /v1/llm/openai/chat-completions/reports/usage` | Org-wide usage (cost, categories, per-key costs) |
| `GET /v1/llm/openai/chat-completions/reports/api-keys-savings` | Per-key savings data |
| `GET /v1/llm/openai/chat-completions/reports/recommendations` | Savings recommendations and potential savings |
| `GET /v1/llm/openai/chat-completions/reports/api-keys/{id}/usage` | Per-key token and request detail |

All endpoints use `https://api.cast.ai` as the base URL.

## CI/CD

The GitHub Actions workflow (`.github/workflows/release.yml`) runs on every push to `main` and on PRs:

1. **Build & Test** — compiles the project and runs the test suite
2. **Release** (main only) — on push to main:
   - Determines the next semantic version from commit messages (`feat:` → minor, `BREAKING CHANGE` → major, everything else → patch)
   - Builds a universal binary (arm64 + x86_64) via `scripts/package-app.sh`
   - Code signs with Developer ID certificate (if configured)
   - Notarizes with Apple (if credentials configured)
   - Creates a git tag and GitHub Release with the DMG and SHA256 checksum

### Versioning

Versions follow [Semantic Versioning](https://semver.org/). The workflow auto-detects the bump level:

| Commit message pattern | Version bump |
|----------------------|-------------|
| `feat: ...` or `feat(scope): ...` | Minor (0.1.0 → 0.2.0) |
| `BREAKING CHANGE` in body or `!:` in header | Major (0.1.0 → 1.0.0) |
| Everything else (`fix:`, `chore:`, `docs:`, etc.) | Patch (0.1.0 → 0.1.1) |

### Required secrets (optional — for code signing and notarization)

| Secret | Purpose |
|--------|---------|
| `DEVELOPER_CERTIFICATE_BASE64` | Base64-encoded .p12 Developer ID certificate |
| `DEVELOPER_CERTIFICATE_PASSWORD` | Password for the .p12 certificate |
| `NOTARY_APPLE_ID` | Apple ID for notarization |
| `NOTARY_TEAM_ID` | Apple Developer Team ID |
| `NOTARY_PASSWORD` | App-specific password for notarization |

Without these secrets, the workflow still builds and releases — the app is ad-hoc signed and not notarized. Users may need to right-click → Open on first launch.

## Development

```bash
# Build (debug)
swift build

# Run tests
swift test

# Run locally
swift run KimchiCompanion

# Package release DMG
APP_VERSION=0.1.0 bash scripts/package-app.sh
```

### Inspecting persisted state

```bash
# Keychain entry
security find-generic-password -s "com.kimchicompanion.api-key"

# Disk cache
cat ~/Library/Application\ Support/KimchiCompanion/usage-cache.json | python3 -m json.tool

# UserDefaults preferences
defaults read | grep kimchicompanion
```

## Requirements

- macOS 14 (Sonoma) or later
- A [CAST AI](https://cast.ai) account and API key

## License

MIT
