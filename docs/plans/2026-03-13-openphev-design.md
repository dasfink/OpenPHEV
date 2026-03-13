# OpenPHEV — Design Specification

**Date:** 2026-03-13
**Status:** Approved via brainstorm session

---

## What It Is

An open-source, privacy-first iOS app that monitors a 2023 Hyundai Tucson PHEV through two BLE devices: a Quicklynks BM6 (12V battery sensor) and a Veepeak OBDCheck BLE+ (ELM327 OBD-II adapter). One app, two radios, zero cloud.

## Scope Decisions

- **Platform:** Native Swift / SwiftUI — CoreBluetooth for BLE, CommonCrypto for AES, Swift Charts for sparklines. No cross-platform frameworks. Zero abstraction layers between the app and BLE hardware.
- **Deployment target:** iOS 16+ (iPhone 16 Pro primary test device)
- **Scope:** Unified app (BM6 + OBD-II as equal peers)
- **Vehicle:** 2023 Tucson PHEV Limited AWD only — no multi-vehicle profiles
- **Connectivity:** Bluetooth only — no WiFi OBD adapters
- **Privacy:** No network access, no analytics, no accounts, no cloud
- **License:** Permissive open-source (MIT or similar)

---

## Architecture

### BLE Connection Model

Two peripherals managed by a single `CBCentralManager` with different lifecycles:

**BM6 (passive, always-on):**
- Auto-connects on app launch, scans for device name "BM6"
- Polls every 30 seconds (encrypted command to FFF3, notification from FFF4)
- iOS background BLE execution for background polling
- Auto-reconnects on disconnect
- No user interaction after initial pairing

**Veepeak OBDCheck BLE+ (active, on-demand):**
- User taps "Connect" to scan for ELM327 device
- SwiftOBD2 (MIT) handles AT command init and PID queries
- Auto-disconnects after 5 minutes idle
- No background mode — diagnostics are a "plug in, check, unplug" workflow

### Data Layer

**SQLite via GRDB.swift (MIT)** — one database, two tables:

**`battery_readings`** (BM6, high frequency):
- `id`, `timestamp`, `voltage`, `temperature_c`, `soc_percent`, `is_charging`
- One row every 30 seconds while connected
- Auto-prune rows older than 90 days on app launch

**`ev_health_snapshots`** (OBD-II reports, on demand):
- `id`, `timestamp`, `pack_voltage`, `pack_current`, `soc`, `soh_min`, `soh_max`, `min_cell_v`, `max_cell_v`, `cell_delta`, `min_temp`, `max_temp`, `raw_json`
- One row per health report scan
- `raw_json` stores full decoded response for future parsing
- Same 90-day rolling window

### Notifications

Local push notifications at three thresholds:
- 12.4V — Warning: "Drive or plug in soon"
- 12.0V — Critical: "Drive or plug in immediately"
- 11.6V — Danger: "Sulfation risk, battery damage possible"

No server, no remote push, no entitlements beyond standard local notifications.

---

## OBD-II Diagnostics & EV Battery Health

### Standard OBD-II (always available)

- Read and clear DTCs with human-readable descriptions
- Live standard PID dashboard: coolant temp, RPM, speed, intake temp, engine load

### EV Battery Health Report (auto-detected)

**Two-tier approach with auto-detection on first Veepeak connection:**

1. Send UDS request `22 0101` to ECU header `7E4`
2. If ECU responds on `7EC` → extended PIDs supported → unlock full health report
3. If timeout/error → flag unsupported → show standard OBD-II only
4. Cache the result per session

**Tier 1 (standard OBD-II):** Pack voltage, reported SOC, battery current.

**Tier 2 (extended Hyundai BMS, if detected):**
- **PID `2101`:** Pack voltage, current, SOC, min/max cell voltage, min/max battery temp, module temperatures 1–8
- **PID `2105`:** Cell voltage deviation, SOH (deterioration min/max), additional module temps
- Formulas derived from community PID database (Kia Soul EV, Ioniq, Niro, Kona — same BMS architecture across Hyundai/Kia platform)

**Risk assessment:** UDS Service `22` (ReadDataByIdentifier) is read-only. Cannot write, reset, or modify anything. If the ECU doesn't recognize the PID, it returns a standard error response. The car ignores it. No write services (`2E`), no session control (`10`), no routine control (`31`) are ever used.

**Vehicle profile:** A `TucsonPHEV2023` struct holds PID definitions, byte offsets, formulas, and display names. One-file change if PIDs need adjustment after real-world testing.

---

## UI/UX Design

### Design Philosophy

**Bauhaus + Tufte:**
- Form follows function — every element earns its place
- Maximum data-ink ratio — no chartjunk
- Color is data, not decoration — monochrome UI, color only for status semantics
- Typography does the heavy lifting

### Visual System

- **Palette:** Near-monochrome (black, #111 cards, gray text). Color reserved for status:
  - Green (#4ade80) — Fully charged / Healthy
  - Yellow (#facc15) — Warning
  - Orange (#f97316) — Critical
  - Red (#ef4444) — Danger
- **Typography:** IBM Plex Mono for data values, IBM Plex Sans for labels (or SF Mono / SF Pro on iOS)
- **Layout:** Structured cards on a dark background — Bauhaus geometric containment

### Information Architecture

**Single continuous scroll — no tabs, no modals:**

**1. 12V Battery Hero (always visible, no scroll needed)**
- Large monospace voltage number (e.g., `12.63V`) colored by status
- Secondary line: temperature, SOC%, charging status — muted gray
- Card: 24-hour voltage sparkline with threshold lines (12.4V, 12.0V)

**2. 12V Statistics Card**
- Today min/max, 7-day average
- Compact data rows

**3. EV Battery Card**
- **Disconnected state:** Subtle dashed-border card with muted text — "Connect Veepeak to scan"
- **Tier 1 connected:** Pack voltage, SOC, current in data rows
- **Tier 2 detected:** 2x2 grid — SOH%, SOC, pack voltage, current. Separate cell balance card with min/max cell voltage, delta, temperature spread

**4. Diagnostics Card**
- **Disconnected:** Same subtle dashed placeholder
- **Connected:** DTC count and codes (tap to expand). Live PID data in compact rows

### Empty States

When Veepeak is not connected, EV and Diagnostics cards appear as subtle dashed-border placeholders. The 12V battery dominates the screen. The app feels like a focused battery monitor until you choose to connect the OBD adapter.

### Connection UX

No status bars or connection chrome. Connection state is contextual:
- BM6 section shows live data = it's connected
- EV section shows "Connect Veepeak" = it's not
- BM6 disconnect triggers reconnect silently; failure shows inline status

---

## Dependencies

| Dependency | License | Purpose |
|-----------|---------|---------|
| SwiftOBD2 | MIT | ELM327 BLE communication |
| GRDB.swift | MIT | SQLite wrapper |
| CommonCrypto | Apple | AES-128-CBC for BM6 protocol |
| CoreBluetooth | Apple | BLE central manager |
| SwiftUI | Apple | UI framework |
| Charts | Apple | Sparklines and history charts |

---

## Project Structure

```
OpenPHEV/
├── OpenPHEV.xcodeproj/
├── OpenPHEV/
│   ├── App/
│   │   └── OpenPHEVApp.swift
│   ├── BLE/
│   │   ├── BLEManager.swift              # Single CBCentralManager
│   │   ├── BM6Connection.swift           # BM6-specific BLE logic
│   │   └── OBDConnection.swift           # Veepeak/SwiftOBD2 wrapper
│   ├── Crypto/
│   │   └── BM6Crypto.swift               # AES-128-CBC encrypt/decrypt
│   ├── Models/
│   │   ├── BatteryReading.swift          # 12V data model + GRDB record
│   │   ├── EVHealthSnapshot.swift        # EV health data model + GRDB record
│   │   └── TucsonPHEV2023.swift          # Vehicle profile + PID definitions
│   ├── Data/
│   │   ├── Database.swift                # GRDB setup, migrations, pruning
│   │   └── BatteryStore.swift            # Read/write queries
│   ├── Views/
│   │   ├── ContentView.swift             # Single scroll container
│   │   ├── BatteryHeroView.swift         # 12V hero number + meta
│   │   ├── VoltageChartCard.swift        # Sparkline + thresholds
│   │   ├── BatteryStatsCard.swift        # Min/max/avg statistics
│   │   ├── EVHealthCard.swift            # EV battery health report
│   │   ├── CellBalanceCard.swift         # Cell voltage + temp spread
│   │   ├── DiagnosticsCard.swift         # DTCs + live PIDs
│   │   └── PlaceholderCard.swift         # Dashed-border empty state
│   ├── Notifications/
│   │   └── AlertManager.swift            # Local push notification logic
│   └── Assets.xcassets/
├── docs/
│   └── plans/
│       └── 2026-03-13-openphev-design.md # This file
└── README.md
```

---

## Open Questions

1. **Tucson PHEV PID confirmation:** Will `7E4/2101` and `7E4/2105` respond on the 2023 Tucson PHEV? Testing required with real hardware.
2. **Background BLE limits:** iOS background BLE execution has restrictions. Testing needed to confirm 30-second polling works reliably when app is backgrounded.
3. **SwiftOBD2 BLE compatibility:** Need to verify SwiftOBD2 works with Veepeak OBDCheck BLE+ specifically (BLE, not Bluetooth Classic).
4. **Charts framework:** Apple's Swift Charts (iOS 16+) vs. a lightweight custom sparkline view.
