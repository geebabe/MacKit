<div align="center">

# ⚡ MacKit

**A native, production-minded macOS productivity toolkit built for daily personal use.**  
*Fast, private, elegant, and dependency-free.*

[![Platform: macOS 26+](https://img.shields.io/badge/platform-macOS%2026%2B-black?style=for-the-badge&logo=apple)](https://www.apple.com/macos/)
[![Architecture: Apple Silicon](https://img.shields.io/badge/arch-Apple%20Silicon-orange?style=for-the-badge&logo=apple)](https://www.apple.com/mac/)
[![Language: Swift 6](https://img.shields.io/badge/Swift-6.0-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![UI: SwiftUI & AppKit](https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-007AFF?style=for-the-badge)](https://developer.apple.com)
[![Tests: 85 Passed](https://img.shields.io/badge/Tests-85%20Passed-34C759?style=for-the-badge&logo=checkmarx)](https://github.com)
[![Privacy: Zero Telemetry](https://img.shields.io/badge/Privacy-100%25%20Local%20%26%20Encrypted-blueviolet?style=for-the-badge&logo=shield)](https://github.com)

</div>

---

## ✦ Overview

**MacKit** unifies the three most essential daily Mac utilities into a single, cohesive, ultra-lightweight (1.6 MB) native application:

1. **📋 Encrypted Clipboard Manager** — Spotlight/Raycast-grade split HUD with rich inspectors, search, and tamper-resistant storage.
2. **🪟 Native Window Manager** — Instant keyboard-driven snap, maximize, center, and restore actions.
3. **🔀 Window Switcher** — Per-window MRU focus switcher with unminimize support and app icon badges.

Built strictly with **Swift 6, SwiftUI, AppKit, CryptoKit, and SQLite**. Zero third-party dependencies. Zero private SPIs. Zero network access.

---

## ✦ Key Features

### 1. 📋 Clipboard Manager (`⌥V`)
- **Spotlight/Raycast-Style Split HUD:** Wide 760×480 px floating interface with frosted glass vibrancy (`.ultraThinMaterial`).
- **Rich Inspectors:**
  - **Text & Code:** Live scrollable view with character & word counts, line wrap, and monospaced syntax detection.
  - **Links:** Domain recognition card with one-click *"Open in Browser"*.
  - **Images & Screenshots:** Scaled preview thumbnails with dimensions and size metadata.
- **Category Filter Pills:** Instantly switch between `All`, `Text`, `Links`, `Images`, and `Pinned`.
- **Quick-Paste Hotkeys:** Press `⌘1` through `⌘9` to immediately paste any of the top 9 clips.
- **CryptoKit AES-256-GCM:** Payloads are authenticated and encrypted at rest with keys protected by the macOS Keychain.
- **Privacy Filters:** Automatic rejection of concealed types (`org.nspasteboard.ConcealedType`, 1Password, Bitwarden, KeePass).

### 2. 🪟 Window Manager (`⌃⌥←`, `⌃⌥→`, `⌃⌥↑`, `⌃⌥↓`, `⌃⌥C`)
- **Pure Native Geometry:** Converts Cocoa screen coordinates to Accessibility coordinates cleanly.
- **Pixel-Accurate Snapping:** Left 50% and Right 50% snapping handles odd-width screen dimensions without gaps.
- **Smart Restore:** Caches window frames before snapping; `⌃⌥↓` restores the exact pre-snap position.
- **Boundary Clamping:** Windows are clamped within usable screen space, respecting the menu bar and Dock.

### 3. 🔀 Window Switcher (`⌃⌥Space`)
- **True Per-Window MRU:** Tracks focus changes in real time, placing the most recently used window at the top.
- **Multi-Window Navigation:** Differentiates between multiple windows of the same application.
- **Unminimize on Activate:** Seamlessly restores minimized windows and brings them to the front.
- **Keyboard Navigation:** Cycle using `Tab` / `Shift-Tab` or arrow keys; filter on the fly with live search.

### 4. ⚙️ App Shell & Security Guard
- **Menu Bar Accessory:** Lives quietly in the status bar (`LSUIElement`) with quick actions and pause/resume toggles.
- **Dedicated Settings:** Multi-tab SwiftUI Preferences with real-time Permission monitoring, Shortcut conflict detection, and Launch at Login.
- **Carbon Global Hotkeys:** System-wide shortcut dispatch that intercepts keys without typing unwanted symbols (`√`) into documents.

---

## ✦ Keyboard Shortcuts

| Shortcut | Action | Description |
| :--- | :--- | :--- |
| <kbd>⌥</kbd> <kbd>V</kbd> | **Toggle Clipboard History** | Opens the split-view clipboard manager HUD |
| <kbd>⌘</kbd> <kbd>1</kbd>–<kbd>9</kbd> | **Quick Paste** | Immediately pastes the corresponding history item |
| <kbd>P</kbd> | **Pin / Unpin** | Toggles pin state (pinned items survive retention cleanup) |
| <kbd>⌫</kbd> | **Delete Clip** | Deletes the selected item and securely removes payload file |
| <kbd>⌃</kbd> <kbd>⌥</kbd> <kbd>←</kbd> | **Snap Left** | Snaps focused window to the left half of the display |
| <kbd>⌃</kbd> <kbd>⌥</kbd> <kbd>→</kbd> | **Snap Right** | Snaps focused window to the right half of the display |
| <kbd>⌃</kbd> <kbd>⌥</kbd> <kbd>↑</kbd> | **Maximize** | Expands focused window to full usable screen bounds |
| <kbd>⌃</kbd> <kbd>⌥</kbd> <kbd>↓</kbd> | **Restore** | Returns window to its frame prior to snapping |
| <kbd>⌃</kbd> <kbd>⌥</kbd> <kbd>C</kbd> | **Center Window** | Centers focused window on the active display |
| <kbd>⌃</kbd> <kbd>⌥</kbd> <kbd>Space</kbd> | **Window Switcher** | Opens the per-window MRU switcher HUD |
| <kbd>Esc</kbd> | **Dismiss** | Closes any open HUD overlay without action |

---

## ✦ Architecture

MacKit is structured as a **modular monolith** with strict boundary separation and Swift 6 concurrency isolation:

```
MacKit
├── Sources/
│   ├── MacKitApp/          # App entry point, AppDelegate, Menu bar, Settings UI
│   ├── AppCore/            # Settings, Launch at Login, Permissions, GlobalHotkeyManager
│   ├── ClipboardFeature/   # Observer, Filters, In-memory Search, Split HUD UI
│   ├── WindowFeature/      # Geometry engine, AXUIElement wrapper, Restore store
│   ├── SwitcherFeature/    # Window enumerator, MRU tracker, Activator, Switcher HUD
│   ├── SecureStorage/      # SQLite (WAL mode), CryptoKit AES-GCM, PayloadStore
│   └── Diagnostics/        # Redacted structured logging, Error categories
└── Tests/
    ├── AppCoreTests/
    ├── ClipboardFeatureTests/
    ├── DiagnosticsTests/
    ├── SecureStorageTests/
    ├── SwitcherFeatureTests/
    └── WindowFeatureTests/
```

### Privacy & Security Guarantees
- **Zero Plaintext Payloads on Disk:** Payloads are encrypted with CryptoKit `AES-256-GCM` before being written to disk in a `0700` POSIX directory.
- **Tamper Evidence:** Modifying even a single bit of a stored payload triggers an authentication failure; corrupted data is rejected.
- **No Secret Leaks:** Logging automatically suppresses and redacts clipboard contents, URLs, and secrets.
- **Zero Network Entitlements:** MacKit contains no networking code or telemetry SDKs.

---

## ✦ Build & Installation

### Requirements
- **macOS:** 26.0+ (Tested on macOS 27 Sequoia)
- **Architecture:** Apple Silicon (`arm64`)
- **Tools:** Swift 6.0+ / Xcode Command Line Tools

### 1. Build & Run Tests
```bash
# Clone the repository
git clone https://github.com/your-username/MacKit.git
cd MacKit

# Run the full automated test suite (85 tests)
swift test
```

### 2. Build Release Application Bundle
```bash
# Builds optimized binary and packages into dist/MacKit.app with ad-hoc signature
./Scripts/build_app.sh release
```

### 3. Install for Daily Use
```bash
# Copy to your Applications directory
cp -R dist/MacKit.app /Applications/

# Launch MacKit
open /Applications/MacKit.app
```

### 4. Grant Accessibility Permission
On first launch, MacKit will automatically prompt for **Accessibility** permission. Toggle MacKit to **On** under:  
*System Settings → Privacy & Security → Accessibility*.

---

## ✦ Definition of Done & Quality

MacKit was developed using a strict milestone-driven protocol:
- **85 Automated Tests:** Comprehensive unit and integration coverage across SQLite transactions, CryptoKit encryption, retention rules, geometry math, MRU ordering, and error recovery.
- **Zero Compiler Warnings:** Built with Swift 6 strict concurrency checks.
- **Lightweight Footprint:** ~1.6 MB release binary with negligible idle CPU and memory consumption.

---

<div align="center">
<sub>Crafted with precision for macOS. Strictly original code.</sub>
</div>

