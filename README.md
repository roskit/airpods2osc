# AirPods OSC Bridge by Roskit

A native macOS 14+ menu-bar bridge for headphone motion data. It uses `CMHeadphoneMotionManager` callback delivery, processes orientation on a dedicated serial `OperationQueue`, and sends small OSC UDP datagrams with `Network.framework`. It has no runtime dependencies.

## Design choices

- **Native and minimal:** SwiftUI, CoreMotion, and Network.framework keep the app small, responsive, and free of third-party runtime dependencies.
- **Motion off the UI thread:** CoreMotion callbacks, calibration, rate limiting, and packet preparation run on a dedicated serial queue. SwiftUI receives only coalesced diagnostics.
- **Quaternion-first orientation:** Calibration stores a neutral `CMAttitude` and calculates relative orientation before converting to Euler angles. This avoids using Euler angles as the internal reference frame.
- **Small OSC surface:** A local encoder writes the fixed OSC message formats directly, including 4-byte padding and big-endian numeric values, rather than adding an OSC dependency.
- **Low-latency local transport:** Independent UDP packets are scheduled through `NWConnection` without batching. A configurable send-rate limit bounds downstream work while preserving current motion data.

## File tree

```text
AirPodsOSCBridge/
  AirPodsOSCBridgeApp.swift        Replace the Xcode template app file
  AppState.swift
  HeadphoneMotionService.swift
  OSCEncoder.swift
  OSCSender.swift
  SettingsStore.swift
  MenuBarView.swift
  SettingsView.swift
  Info.plist
  AirPodsOSCBridge.entitlements
AirPodsOSCBridgeTests/
  OSCEncoderTests.swift
```

## Xcode setup

1. Open [AirPodsOSCBridge.xcodeproj](AirPodsOSCBridge.xcodeproj) in Xcode 15 or later. The app and XCTest targets are already configured for macOS 14.0.
2. In **Signing & Capabilities**, choose your Development Team and replace the placeholder `com.example.AirPodsOSCBridge` bundle identifier with one you control.
3. The target already points to [Info.plist](AirPodsOSCBridge/Info.plist), which makes the app a menu-bar agent and includes the required `Privacy - Motion Usage Description` value. It also uses [AirPodsOSCBridge.entitlements](AirPodsOSCBridge/AirPodsOSCBridge.entitlements) for App Sandbox outgoing connections.
4. Build and run on Apple Silicon with compatible AirPods connected. Run the `AirPodsOSCBridgeTests` scheme to validate OSC byte encoding.

`NSMotionUsageDescription` is required. Starting motion updates causes macOS to request access when needed; macOS does not expose a separate headphone-motion authorization-status API, so a denied request surfaces through the update error path.

## OSC schema

Each message is an independent UDP datagram sent to the configured host and port, defaulting to `127.0.0.1:9000`.

| Address | Types | Values |
| --- | --- | --- |
| `/airpods/head/quaternion` | `ffff` | `qw qx qy qz` |
| `/airpods/head/euler` | `fff` | `yaw pitch roll` in radians |
| `/airpods/head/gyro` | `fff` | radians/second around `x y z` |
| `/airpods/head/accel` | `fff` | user acceleration `x y z` in g |
| `/airpods/status` | `i` | `1` while valid data streams, otherwise `0` |

Quaternion is the canonical form. Recenter saves a copy of the current `CMAttitude`; each callback applies `multiply(byInverseOf:)` to a fresh attitude copy before extracting quaternion or Euler outputs. No calibration depends on Euler angles.

## Manual test procedure

1. Connect compatible AirPods, enable their head tracking where appropriate, then launch the app.
2. The menu icon should show `Ready`. Press **Start** and grant the motion permission if prompted.
3. Confirm `Streaming`, rising packet count, and changing yaw/pitch/roll while moving your head.
4. Press Command-K or **Recenter** while facing forward. The Euler values should move close to zero, then change relative to the new forward orientation.
5. Change host, port, or output toggles in Settings while streaming. The sender recreates its `NWConnection` after a destination change.
6. Press **Stop**. The app stops CoreMotion updates, emits `/airpods/status 0`, and cancels the UDP connection.

## Receiver smoke test

Install a temporary OSC receiver with Python's `python-osc` package, then run:

```python
from pythonosc.dispatcher import Dispatcher
from pythonosc.osc_server import BlockingOSCUDPServer

dispatcher = Dispatcher()
dispatcher.set_default_handler(lambda address, *values: print(address, values))
BlockingOSCUDPServer(("127.0.0.1", 9000), dispatcher).serve_forever()
```

This script is only a test receiver; the bridge itself does not use Python or any third-party package.

## Latency and limits

The bridge avoids polling, batching, and main-thread processing. At the default 100 Hz rate, each packet is synchronously encoded on the serial motion queue then scheduled asynchronously to the Network queue. Localhost UDP transport normally contributes very little latency; CoreMotion delivery cadence and the receiver's processing are likely larger contributors. The UI only receives coalesced diagnostics, so it does not contend with the real-time callback path.

## MVP acceptance criteria

- Menu-bar launch, Start/Stop, destination configuration, and Command-K recenter work.
- Compatible headphones deliver callback-based `CMDeviceMotion` samples.
- Valid OSC datagrams are observable at `127.0.0.1:9000`.
- Quaternion, optional Euler, gyro, acceleration, and status messages use the documented schema.
- Recenter produces orientation relative to the new neutral pose.
- Streaming keeps motion processing off the main actor and uses no external runtime dependencies.

## Future extensions

- Add selectable Euler conventions and degrees output.
- Add OSC bundles only if a receiver specifically benefits from atomic multi-message frames.
- Add selectable reference frames, sequence numbers, and CSV capture diagnostics.
- Add automated integration tests with a local UDP decoder.

## Additional note

- Made with the help of AI Agent