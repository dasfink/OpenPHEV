# OpenPHEV — Session Handoff

**Date:** 2026-03-13
**Status:** Mid-brainstorm — scope decision pending, then design + implementation

---

## What Is This?

An open-source, privacy-first iOS app for monitoring a 2023 Hyundai Tucson PHEV. Replaces two closed/privacy-hostile apps (Quicklynks BM6 app, Car Scanner ELM OBD2) with a single unified tool. Will be published under a permissive open-source license.

## Hardware

| Device | What It Does | Connection | Status |
|--------|-------------|------------|--------|
| Quicklynks BM6 | 12V battery sensor (voltage, temp, SOC) | BLE, proprietary AES-encrypted protocol | Arriving Mar 13 |
| Veepeak OBDCheck BLE+ | OBD-II adapter (DTCs, live data, enhanced PIDs) | BLE, ELM327 AT commands over GATT serial | Arriving Mar 13 |

## Vehicle

- 2023 Hyundai Tucson Plug-In Hybrid Limited AWD
- 12V battery under cargo floor, jump terminals under hood
- Known problem: PHEV parasitic draw drains 12V if car sits 2-3 weeks without driving or plugging in
- Traction battery: 360V, maintained by DC-DC converter when car is in Ready mode

## What's Been Done

### 1. BM6 BLE Protocol — Fully Reverse-Engineered (by community, implemented by us)

The BM6 protocol is solved. Key details:
- **Service UUID:** FFF0
- **Write characteristic:** FFF3 (send AES-encrypted commands)
- **Notify characteristic:** FFF4 (receive AES-encrypted responses)
- **AES-128-CBC key:** `[0x6C, 0x65, 0x61, 0x67, 0x65, 0x6E, 0x64, 0xFF, 0xFE, 0x30, 0x31, 0x30, 0x30, 0x30, 0x30, 0x39]`
- **IV:** 16 zero bytes
- **Data request command:** encrypt `d1550700000000000000000000000000`, write to FFF3
- **Response parsing (hex string of decrypted 16 bytes):**
  - `[0:6]` = header `d15507`
  - `[6:8]` = temp sign (`01` = negative)
  - `[8:10]` = temperature °C
  - `[12:14]` = SOC %
  - `[14:18]` = voltage × 100

Protocol verified against Python reference — encryption output matches byte-for-byte.

### 2. iOS App Prototype — BM6 Only (complete, needs Xcode build test)

A complete Xcode project exists at `BM6Monitor/`:

```
BM6Monitor/
├── BM6Monitor.xcodeproj/project.pbxproj
├── BM6Monitor/
│   ├── BM6MonitorApp.swift          # App entry point
│   ├── ContentView.swift            # SwiftUI views (gauge, cards, chart, scanner sheet)
│   ├── BLEManager.swift             # CoreBluetooth central manager
│   ├── BM6Crypto.swift              # AES-128-CBC via CommonCrypto
│   ├── BM6Data.swift                # Packet parser, data models, alert thresholds
│   ├── Info.plist                   # BLE permissions + background mode
│   └── Assets.xcassets/             # App icon placeholder, accent color
└── README.md                        # Setup instructions for iPhone deployment
```

**Features implemented:**
- BLE scan for devices named "BM6"
- Connect, encrypt init command, subscribe to notifications
- Decrypt + parse voltage, temperature, SOC
- Arc gauge, detail cards, status banner with alert thresholds
- Voltage history chart with 12.4V/12.0V threshold lines
- Auto-reconnect on disconnect
- 30-second polling interval
- Dark mode, device scanner sheet

**Alert thresholds:**
- 12.6V+ = Fully charged (green)
- 12.4V = Warning (yellow) — "Drive or plug in soon"
- 12.0V = Critical (orange) — "Drive or plug in immediately"
- <11.6V = Danger (red) — "Sulfation risk, battery damage possible"

**NOT yet tested on device** — needs Xcode build, signing, and deployment to iPhone 16 Pro.

### 3. Veepeak OBDCheck BLE+ — Research Complete

Key finding: **No reverse engineering needed.** The Veepeak is an ELM327 v2.2 adapter. It creates a BLE-to-serial bridge using standard GATT, then you send plain-text AT commands and OBD-II PIDs over it. This is a well-documented open standard.

**Existing Swift libraries (all MIT licensed):**
- [SwiftOBD2](https://github.com/kkonteh97/SwiftOBD2) — most active, SPM, BLE+WiFi, async/await
- [LTSupportAutomotive](https://github.com/mickeyl/LTSupportAutomotive) — mature, includes VIN decoder
- [OBD2_BLE](https://github.com/waruc/OBD2_BLE) — lightweight, CocoaPods

**The Tucson PHEV gap:** Standard OBD-II PIDs give generic engine data. The deep traction battery diagnostics (cell voltages, SOH, temperatures) require Hyundai-specific extended PIDs that talk to the BMS ECU via UDS. These PIDs have **not been published** for the 2023 Tucson PHEV:
- [JejuSoul/OBD-PIDs-for-HKMC-EVs](https://github.com/JejuSoul/OBD-PIDs-for-HKMC-EVs) covers older models but Tucson PHEV is an [open issue since 2024](https://github.com/JejuSoul/OBD-PIDs-for-HKMC-EVs/issues/65)
- Car Scanner app has these PIDs internally but doesn't publish them
- PHEV Watchdog (Android-only) proves the data IS accessible on Hyundai/Kia PHEVs
- Sniffing traffic between Car Scanner and Veepeak could capture the UDS requests — a future reverse engineering project

### 4. Feature Landscape — Researched

**What the Quicklynks BM6 app does (what we're fully replacing):**
- Real-time voltage, temperature, SOC
- Cranking system test (voltage drop during engine start)
- Charging system test (DC-DC converter / alternator output)
- 35-day offline data buffer on BM6 hardware, auto-sync over BLE
- Voltage history graphs
- Low-battery push notifications
- Multi-battery profiles
- Trip timestamps
- GPS "find my car" and trip recording with route map
- Privacy nightmare: sends everything to servers in China

**What Car Scanner ELM OBD2 does (what we're partially replacing):**
- Standard OBD-II: read/clear DTCs, live sensor data, freeze frames, VIN
- Custom dashboard with configurable gauges, HUD mode
- Data logging with CSV export
- Acceleration testing (0-60)
- Trip computer with fuel stats
- Hyundai/Kia enhanced profiles: brake bleeding, transmission adaptation, service interval
- Custom extended PIDs for manufacturer-specific battery data
- Paid app, closed source

## Where We Left Off — The Design Decision

We were mid-brainstorm on app scope. The user chose **"OpenPHEV"** as the project name, suggesting they're leaning toward the broader unified vision rather than a BM6-only tool.

**Three approaches were presented (visual companion at localhost:60064):**

1. **A — 12V Guardian:** Focused BM6 dashboard. Ship fast, add OBD-II later.
2. **B — TucsonKit (now OpenPHEV):** Unified app, BM6 + OBD-II as equal peers. One app, two radios.
3. **C — HyundaiEV / Platform:** Extensible diagnostic app for all Hyundai/Kia PHEVs with pluggable vehicle profiles.

**The user has NOT yet picked A/B/C.** Resume the brainstorm here.

## Next Steps

1. **Get scope decision** (A/B/C) — resume brainstorming skill
2. **Ask remaining clarifying questions** — data persistence strategy, notification approach, what OBD-II features matter most day-one vs later
3. **Propose architecture** — present design for the chosen scope
4. **Write design spec** — `docs/superpowers/specs/` per brainstorming skill process
5. **Build** — the BM6 side is already implemented; OBD-II side uses SwiftOBD2 (MIT)
6. **Test on device** — both devices arrive today (Mar 13)

## Key Open-Source Resources

| Resource | URL | What It Gives Us |
|----------|-----|-----------------|
| BM6 Python reference | https://github.com/JeffWDH/bm6-battery-monitor | Protocol implementation we verified against |
| BM6 ESPHome component | https://github.com/andrewbackway/esphome-bm6_ble | ESP32-S3 integration (separate from iOS app) |
| BM6 protocol writeup | https://www.tarball.ca/posts/reverse-engineering-the-bm6-ble-battery-monitor/ | Full reverse engineering walkthrough |
| SwiftOBD2 | https://github.com/kkonteh97/SwiftOBD2 | MIT, drop-in ELM327 BLE stack for iOS |
| Hyundai/Kia PIDs | https://github.com/JejuSoul/OBD-PIDs-for-HKMC-EVs | Community PID database (Tucson PHEV missing) |
| PHEV Watchdog | https://phevwatchdog.net/ | Android-only, proves data is accessible |
| BM2 reference | https://github.com/KrystianD/bm2-battery-monitor | Similar protocol, ESPHome template |
| HA integration | https://github.com/Rafciq/BM6 | Home Assistant custom component |

## File Map

```
OpenPHEV/
├── BUILD-BRIEF.md              # Original hardware + software requirements
├── HANDOFF.md                  # This file
├── BM6Monitor/                 # iOS Xcode project (BM6-only prototype)
│   ├── BM6Monitor.xcodeproj/
│   ├── BM6Monitor/             # Swift source files
│   └── README.md               # Build + deploy instructions
└── .superpowers/               # Visual companion brainstorm artifacts
```
