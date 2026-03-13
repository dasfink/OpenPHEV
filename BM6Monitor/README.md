# BM6 Monitor — iOS App

A privacy-first iOS app that connects directly to the Quicklynks BM6 battery sensor via Bluetooth Low Energy. No cloud, no accounts, no data leaves your phone.

Built for monitoring the 12V battery on a 2023 Hyundai Tucson PHEV.

## What It Does

- Scans for and connects to BM6 sensors over BLE
- Decrypts AES-128-CBC packets using the reverse-engineered protocol
- Displays real-time voltage, temperature, and state of charge
- Color-coded status with alert thresholds (12.4V warn, 12.0V critical)
- Voltage history chart with threshold lines
- Auto-reconnects if BLE connection drops
- Polls every 30 seconds while connected

## Requirements

- iPhone running iOS 17+ (tested targeting iPhone 16 Pro)
- Xcode 15.4+ on a Mac
- Apple Developer account (free tier works for personal device deployment)
- Quicklynks BM6 sensor installed on vehicle

## Setup — Deploy to Your iPhone

### 1. Open in Xcode

Double-click `BM6Monitor.xcodeproj` to open the project.

### 2. Set Your Signing Team

1. Click the **BM6Monitor** project in the left sidebar
2. Select the **BM6Monitor** target
3. Go to **Signing & Capabilities** tab
4. Check **Automatically manage signing**
5. Select your **Team** from the dropdown
   - If you don't have one, sign in with your Apple ID via Xcode → Settings → Accounts
6. Change the **Bundle Identifier** to something unique, e.g. `com.yourname.bm6monitor`

### 3. Connect Your iPhone

1. Plug your iPhone 16 Pro into your Mac with a USB-C cable
2. On first connection, trust the computer on your iPhone
3. Select your iPhone from the device dropdown at the top of Xcode (not a simulator — BLE doesn't work in simulators)

### 4. Build and Run

1. Press **Cmd+R** or click the Play button
2. First time: your iPhone may show "Untrusted Developer" — go to **Settings → General → VPN & Device Management** and trust your developer certificate
3. The app will launch on your phone

### 5. Allow Bluetooth

When the app launches for the first time, iOS will prompt for Bluetooth permission. Tap **Allow**.

## Using the App

1. Open the app near your vehicle (BLE range is ~30 feet)
2. Tap the **antenna icon** in the top right to scan
3. Your BM6 will appear in the list — tap it to connect
4. Voltage, temperature, and SOC update every 30 seconds
5. The voltage history chart builds up over time

## Architecture

```
BM6MonitorApp.swift    — App entry point
ContentView.swift      — All UI views (gauge, cards, chart, scanner)
BLEManager.swift       — CoreBluetooth central manager, scan/connect/poll
BM6Crypto.swift        — AES-128-CBC encrypt/decrypt using CommonCrypto
BM6Data.swift          — Data models, packet parser, battery status enum
Info.plist             — Bluetooth usage descriptions + background mode
```

## Protocol Details

The BM6 uses a proprietary BLE protocol that has been reverse-engineered by the open-source community:

- **Service:** FFF0
- **Write characteristic:** FFF3 (send encrypted commands)
- **Notify characteristic:** FFF4 (receive encrypted responses)
- **Encryption:** AES-128-CBC, zero IV, key from Quicklynks APK
- **Data request:** Send encrypted `d1550700000000000000000000000000` on FFF3
- **Response parsing:** Header `d15507` + temp sign + temp value + SOC + voltage

## Privacy

Zero network access. The app uses only CoreBluetooth to talk to the BM6 sensor. No analytics, no telemetry, no cloud, no accounts. All data stays on your phone.

## Free Developer Account Limitations

With a free Apple Developer account:
- Apps expire after **7 days** — you need to re-deploy from Xcode weekly
- Limited to **3 apps** sideloaded at a time
- No push notifications or certain entitlements

For $99/year, a paid Apple Developer account removes these limits and lets you deploy indefinitely.

## Credits

Protocol reverse engineering by the open-source community:
- [tarball.ca BM6 writeup](https://www.tarball.ca/posts/reverse-engineering-the-bm6-ble-battery-monitor/)
- [JeffWDH/bm6-battery-monitor](https://github.com/JeffWDH/bm6-battery-monitor)
- [andrewbackway/esphome-bm6_ble](https://github.com/andrewbackway/esphome-bm6_ble)
