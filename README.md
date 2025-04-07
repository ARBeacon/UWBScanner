# UWBScanner

Minimal iOS app for testing UWB ranging with [DWM3001CDK](https://www.qorvo.com/products/p/DWM3001CDK) beacons using Apple's Nearby Interaction framework.

## 📱 Features
- Real-time UWB distance measurement (0.1m precision)
- Beacon signal strength (RSSI) monitoring
- 3D direction vector visualization
- Multiple beacon detection and management
- Auto-ranging stabilization algorithm

## 🚀 Quick Start

### Prerequisites
- **Hardware**:
  - iPhone 11 or later (UWB-compatible)
  - DWM3001CDK UWB beacon(s)
  - micro-usb cable for beacon programming
- **Software**:
  - Xcode 16+
  - [J-Flash Lite](https://www.segger.com/products/debug-probes/j-link/technology/flash-download/)

### Hardware Setup
1. Download the [Qorvo Nearby Interaction Firmware](https://www.qorvo.com/products/p/DWM3001CDK#evaluation-tools) for DWM3001CDK board
2. Flash the board using J-Flash Lite:
   - Select device: `NRF52833_XXAA`
   - Program the downloaded Qorvo Nearby Interaction Firmware `.hex` file
   - Verify successful flash

### App Setup
```bash
git clone https://github.com/ARBeacon/UWBScanner.git
```
2. Run the app:

open the project in Xcode and click "Run".