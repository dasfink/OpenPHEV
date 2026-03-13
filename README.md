# OpenPHEV

Open-source, privacy-first iOS app for monitoring the 2023 Hyundai Tucson PHEV.

## What It Does

- **12V Battery Monitoring** — Real-time voltage, temperature, and state-of-charge from a Quicklynks BM6 sensor. Low-voltage alerts at 12.4V, 12.0V, and 11.6V.
- **EV Battery Health** — State-of-health, pack voltage/current, individual cell voltages, and temperature data via Hyundai BMS extended PIDs (ECU 7E4).
- **Diagnostics** — Read and clear diagnostic trouble codes (DTCs) through the OBD-II port.
- **Local-Only** — All data stays on your phone. No cloud, no accounts, no telemetry. SQLite storage with 90-day rolling retention.

## Hardware Required

| Device | Purpose | Connection |
|--------|---------|------------|
| [Quicklynks BM6](https://www.amazon.com/dp/B0BTTM7MK4) | 12V battery sensor | BLE (always-on) |
| [Veepeak OBDCheck BLE+](https://www.amazon.com/dp/B076XVQMJL) | OBD-II adapter | BLE (on-demand) |

The BM6 clamps onto the 12V battery terminals and broadcasts encrypted voltage/temp/SOC data over BLE. The Veepeak plugs into the OBD-II port under the dashboard for EV battery diagnostics.

## Screenshots

<!-- TODO: Add screenshots after first device test -->

## Getting Started

### Prerequisites

- iPhone running iOS 16+
- Xcode 15+ with Swift 5.9
- Both BLE devices (BM6 for basic monitoring, Veepeak for full diagnostics)

### Build & Run

```bash
git clone https://github.com/dasfink/OpenPHEV.git
cd OpenPHEV
open Package.swift  # Opens in Xcode as SPM project
```

Select your iPhone as the run destination, set your development team for code signing, and hit Cmd+R.

### First Launch

1. Grant Bluetooth permission when prompted
2. Grant notification permission (for low-voltage alerts)
3. The app auto-scans for the BM6 — make sure it's on your battery
4. Tap "Connect Veepeak" when ready for EV diagnostics

## Architecture

```
OpenPHEV/
├── App/
│   └── OpenPHEVApp.swift          # @main entry, notification permissions
├── BLE/
│   ├── BLEManager.swift           # CBCentralManager coordinator
│   ├── BM6Connection.swift        # BM6 BLE protocol (FFF0/FFF3/FFF4)
│   └── OBDConnection.swift        # SwiftOBD2 wrapper for Veepeak
├── Crypto/
│   └── BM6Crypto.swift            # AES-128-CBC encrypt/decrypt
├── Data/
│   ├── Database.swift             # GRDB migrations and setup
│   └── BatteryStore.swift         # CRUD for readings and snapshots
├── Models/
│   ├── BM6Data.swift              # BM6Reading, BatteryStatus, BM6Parser
│   ├── BatteryReading.swift       # GRDB BatteryRecord
│   ├── EVHealthSnapshot.swift     # GRDB EVHealthRecord
│   └── TucsonPHEV2023.swift       # Vehicle profile with BMS PIDs
├── Notifications/
│   └── AlertManager.swift         # Low-voltage push alerts
└── Views/
    ├── ContentView.swift          # Main scroll layout
    ├── Theme.swift                # Design tokens (Bauhaus/Tufte)
    ├── BatteryHeroView.swift      # Large voltage display
    ├── VoltageChartCard.swift     # Swift Charts sparkline
    ├── BatteryStatsCard.swift     # Today's min/max/avg
    ├── EVHealthCard.swift         # EV battery data card
    ├── DiagnosticsCard.swift      # DTC display
    ├── PlaceholderCard.swift      # Unconnected feature placeholder
    └── DeviceScannerSheet.swift   # BM6 scanner half-sheet
```

## Dependencies

| Library | License | Purpose |
|---------|---------|---------|
| [GRDB.swift](https://github.com/groue/GRDB.swift) | MIT | SQLite persistence |
| [SwiftOBD2](https://github.com/kkonteh97/SwiftOBD2) | MIT | ELM327/OBD-II communication |

## Vehicle Support

Currently tested with:
- **2023 Hyundai Tucson PHEV** (NX4e)

The BM6 monitoring works with any 12V lead-acid battery. EV battery diagnostics require vehicle-specific PID definitions — contributions for other Hyundai/Kia E-GMP vehicles are welcome.

## BMS Protocol Notes

The Tucson PHEV BMS uses UDS Service 0x22 (Read Data By Identifier) through ECU 7E4 (response 7EC):

- **PID 2101** — Pack voltage, current, SOC, individual cell voltages, module temperatures
- **PID 2105** — Cell voltage deviation, min/max SOH

See `TucsonPHEV2023.swift` for byte offset details.

## Contributing

1. Fork the repo
2. Create a feature branch
3. Commit with descriptive messages
4. Open a PR

Vehicle profile contributions are especially welcome — if you have a Hyundai/Kia with a similar BMS, the PID structure may be identical or very close.

## License

MIT — see [LICENSE](LICENSE) for details.
