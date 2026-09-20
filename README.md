# MacPurge 🧹✨

<p align="center">
  <strong>The Ultimate CleanMyMac Alternative — Built with Modern Swift 6 & SwiftUI for macOS & iOS</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 6.0">
  <img src="https://img.shields.io/badge/Platform-macOS%2014.0%2B%20%7C%20iOS%2017.0%2B-007AFF?style=flat-square&logo=apple&logoColor=white" alt="Platform">
  <img src="https://img.shields.io/badge/Architecture-Observation%20%2B%20Async%2FAwait-34C759?style=flat-square" alt="SwiftUI">
  <img src="https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/App%20Store-Ready-success?style=flat-square" alt="App Store Ready">
</p>

---

## 🌟 Key Features

### ⚡ 1. Smart Care (One-Click Health Scan & Clean)
- **Multi-Pillar Diagnostics**: Scans System Junk, Security/Malware, RAM & Performance, and App Leftovers simultaneously with smooth stage-by-stage visual progression.
- **One-Click Cleaning**: Safely purges selected caches, cleans broken launch agents, flushes DNS, and frees inactive RAM in a single click.

### 🗑️ 2. Deep App Uninstaller
- **Full Footprint Detection**: Scans beyond `/Applications` to automatically locate all associated support data across:
  - `~/Library/Application Support`
  - `~/Library/Caches` & `~/Library/HTTPStorages`
  - `~/Library/Preferences` & `~/Library/Containers`
  - `~/Library/Group Containers` & `~/Library/WebKit`
- **Native App Icons**: Renders native high-resolution macOS icons for each app.
- **Batch Uninstaller**: Select multiple apps and uninstall them completely with zero leftover files.

### 🚀 3. Optimization & Broken Login Items Cleaner
- **Eliminate Lingering Startup Items**: Detects orphaned launch agents, broken daemons, and leftover background items referencing uninstalled software.
- **Background Task Management**: Safely unloads and removes `.plist` entries from `~/Library/LaunchAgents` and `/Library/LaunchDaemons`.
- **System Extension Inspector**: Inspects Preference Panes, QuickLook plugins, and context menu actions.

### 🧠 4. Speed & Maintenance
- **Live Mach Kernel RAM Breakdown**: Real-time memory monitor displaying Active, Wired, Compressed, and Free RAM using native `mach_host_self` kernel stats.
- **Instant Memory Purge**: Reclaims inactive cache memory buffers to boost system responsiveness.
- **DNS Cache Flush**: Resets macOS local DNS cache to solve routing and connection lags.
- **Apple Mail Reindexing**: Rebuilds Mail SQLite databases for faster searching and syncing.
- **Spotlight Search Reindexing**: Triggers background re-indexing of file system metadata.
- **System Maintenance Scripts**: Runs standard UNIX maintenance routines.

### 🔍 5. Space Lens (Visual Disk Visualizer)
- **Storage Tree Analysis**: Proportional, color-coded storage breakdown of your largest directories (`Applications`, `Developer/Xcode`, `Downloads`, `Documents`, `Caches`, `Media`).
- **Quick Actions**: One-click "Reveal in Finder" and direct inspection.

### 🛡️ 6. Privacy & Security
- **Browsing Traces Cleaner**: Scans and cleans histories, cookies, and local database traces across Safari, Google Chrome, Microsoft Edge, Brave, and Mozilla Firefox.
- **Malware & Adware Scanner**: Detects suspicious background daemons, launch agents, and known PUP signatures.

### 📊 7. Menu Bar Companion Widget
- Lightweight `MenuBarExtra` resident widget displaying live RAM usage and Disk space with quick "Free RAM" memory purge shortcut.

---

## 🧱 Architecture & Tech Stack

- **Language**: Swift 6 (Strict Concurrency Model compliant, `@Sendable` safe services).
- **UI Framework**: Modern SwiftUI + AppKit integration for macOS desktop ergonomics.
- **State Management**: `@Observable` macro state machine with MainActor isolation.
- **File & Process Operations**: Detached cooperative background tasks (`Task.detached`), `FileManager`, and `Process` (`launchctl`, `dscacheutil`, `mdimport`).
- **Memory Diagnostics**: Mach Host VM Kernel statistics (`HOST_VM_INFO64`).

---

## 🚀 Building & Running

### Requirements
- **macOS**: Sonoma 14.0 or later (Sequoia 15.0+ fully supported)
- **Xcode**: 15.0 or later (Xcode 16 recommended)
- **Swift**: 6.0 / 5.9

### Quick Start
```bash
# Clone repository
git clone https://github.com/dakshraman/MacPurge.git
cd MacPurge

# Open in Xcode
open MacPurge.xcodeproj
```
Select the **MacPurge_macOS** scheme and press **⌘R** to build and run.

---

## 📦 Distribution & App Store Readiness

- ✅ **Privacy Manifest**: Includes Apple-compliant [`PrivacyInfo.xcprivacy`](CleanerApp/Resources/PrivacyInfo.xcprivacy) declaring required timestamp, disk space, and boot time API categories.
- ✅ **Assets Catalog**: Multiplatform asset catalog configured for macOS and iOS app icon targets.
- ✅ **Continuous Integration**: Pre-configured GitHub Actions CI workflow in [`.github/workflows/build.yml`](.github/workflows/build.yml).

---

## 📄 License
This project is licensed under the [MIT License](LICENSE).
