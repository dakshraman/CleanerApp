# Cleaner App

A native macOS and iOS SwiftUI app that scans and cleans unnecessary files.

## Features

- **System Cache & Temp Files** - Clear app and system caches
- **Duplicate Files** - Find and remove duplicate files (SHA-256)
- **Large & Old Files** - Find files over 100MB hogging space
- **App Logs & Crash Reports** - Remove diagnostic logs
- **iOS Simulator Data** (macOS) - Clean simulator caches and device data
- **Downloads** - Review and organize your Downloads folder
- **Xcode Derived Data** (macOS) - Remove build artifacts and archives

## Setup

### Option 1: Xcode (Recommended)
1. Open Xcode → File → New → Project
2. Choose **Multiplatform** → **App** → Next
3. Set name to "CleanerApp", interface "SwiftUI", language "Swift"
4. Save the project
5. Delete the default files (ContentView.swift, CleanerApp.swift)
6. Copy all files from `CleanerApp/CleanerApp/` into the Xcode project
7. Build & Run (Cmd+R)

### Option 2: XcodeGen
1. Install XcodeGen: `brew install xcodegen`
2. Run `xcodegen` in this directory
3. Open `CleanerApp.xcodeproj`

## Requirements

- macOS 14.0+ / iOS 17.0+
- Xcode 15.0+
