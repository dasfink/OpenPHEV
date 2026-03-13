# BM6 Custom Battery Monitor — Build Brief

## Project Goal

Build a privacy-first 12V battery monitoring system for a 2023 Hyundai Tucson PHEV Limited AWD. Replace the Quicklynks app (which sends GPS and device data to servers in China) with a fully local monitoring solution using open-source tools and an ESP32-S3 microcontroller.

## Vehicle Details

- **Car:** 2023 Hyundai Tucson Plug-In Hybrid Limited AWD
- **12V Battery Location:** Under the cargo floor (not under hood)
- **Jump-Start Terminals:** Under the hood — BM6 and ESP32 will mount here
- **12V Battery Type:** Lead-acid, maintained by DC-DC converter from 360V traction battery
- **Known Issue:** PHEV parasitic draw (BMS, telematics, HVAC controller) can drain 12V if car sits 2-3 weeks without driving or plugging in

## Hardware (Purchased / To Purchase)

| Item | Status | Price | Source |
|------|--------|-------|--------|
| Quicklynks BM6 | Ordered | $30.23 | Walmart, arriving Mar 13 |
| Veepeak OBDCheck BLE+ | Ordered | $45.34 | Amazon, arriving Mar 13 |
| ESP32-S3 (Lolin S3 Pro or DevKitC-1) | To buy | ~$10-15 | Amazon or AliExpress |
| 12V to 5V USB buck converter (mini, waterproof) | To buy | ~$5-8 | Amazon |
| Add-a-fuse adapter (match fuse box size) | To buy | ~$3-5 | Amazon |
| Small waterproof enclosure for ESP32 | To buy | ~$5-8 | Amazon |

**Estimated total for DIY stack:** ~$35-48 (ESP32 + buck converter + fuse tap + enclosure)

## Physical Install

- **BM6:** Ring terminals bolt directly to the under-hood jump-start positive stud and ground point
- **ESP32-S3:** Powered via 12V-to-5V buck converter, tapping 12V from fuse box (add-a-fuse adapter on always-on slot) or from the jump terminal leads
- Both devices sit in the engine bay. BM6 on the terminals, ESP32 nearby in a small enclosure
- ESP32 draws ~40-100mA — negligible compared to PHEV's existing parasitic draw

## Software Architecture

The BM6 is a BLE (Bluetooth Low Energy) sensor. The protocol has been fully reverse-engineered. Data is AES-encrypted, but the key has been extracted. The ESP32-S3 connects to the BM6 over BLE, decrypts voltage and temperature data, and exposes it via ESPHome sensors.

### Key BLE Details

- GATT characteristic UUID: FFF4
- AES-encrypted packets — key extracted from Quicklynks APK
- First byte = packet type, subsequent bytes = voltage value
- Also reports: temperature, state of charge, charging status

## Open-Source Resources

### ESPHome Component (Primary — use this)

- **Repo:** https://github.com/andrewbackway/esphome-bm6_ble
- Optimized for ESP32-S3 with ESP-IDF framework
- Requires ESPHome 2026.2.0+, NimBLE Bluetooth stack
- Tested on Lolin S3 Pro
- Exposes: voltage, temperature, SOC, charging status as ESPHome sensors

### Python Reference Implementation

- **Repo:** https://github.com/JeffWDH/bm6-battery-monitor
- Standalone Python script, reads BM6 from any computer with Bluetooth
- Good for quick testing before setting up ESPHome
- Can run on phone via Termux (Android) or laptop

### Full Protocol Documentation

- **Blog:** https://www.tarball.ca/posts/reverse-engineering-the-bm6-ble-battery-monitor/
- Complete reverse engineering walkthrough
- AES key extraction method
- Packet structure documentation

### Home Assistant Integration

- **Repo:** https://github.com/Rafciq/BM6
- Custom component for HA
- Direct BLE connection from HA hub

### BM2 Reference (Similar Protocol)

- **Repo:** https://github.com/KrystianD/bm2-battery-monitor
- Python connector + ESPHome template
- Includes reverse engineering docs at `.docs/reverse_engineering.md`

## Deliverables for Build Session

1. **ESPHome YAML config** — ESP32-S3 connects to BM6, reads voltage/temp/SOC, exposes sensors over WiFi
2. **Hardware wiring diagram** — 12V tap -> buck converter -> ESP32, BM6 on jump terminals
3. **Alert thresholds** — warn at 12.4V, critical at 12.0V
4. **Home Assistant dashboard (optional)** — voltage history graph, temperature, alerts
5. **Standalone fallback** — Python script for direct BM6 reading without HA

## Alert Logic

| Voltage | Status | Action |
|---------|--------|--------|
| 12.6V+ | Fully charged | Normal |
| 12.4V | Warning | Drive or plug in soon |
| 12.0V | Critical | Drive or plug in immediately |
| < 11.6V | Danger | Sulfation risk, battery damage possible |

The traction battery's DC-DC converter maintains the 12V while the car is in Ready mode. The risk window is when the car sits off and unplugged for extended periods.

## Privacy Requirements

- No data leaves the local network
- No Quicklynks app installed on any device
- No cloud accounts or third-party services
- All data stays on ESP32 -> Home Assistant (local) or read directly via Python script
- GPS/location tracking: none

## Companion Diagnostic Tool

The Veepeak OBDCheck BLE+ (arriving Mar 13) pairs with the Car Scanner ELM OBD2 app for periodic deep diagnostics:

- Traction battery state of health (SOH)
- Individual cell voltages and temperatures
- 12V system voltage (cross-reference with BM6)
- EV range calibration data
- Charging history and regen stats

This is a separate, manual diagnostic tool — plug into OBD2 port under steering column when you want to check traction battery health. The BM6/ESP32 system handles always-on 12V monitoring.
