# ScreenTimePool

An iOS app built on Apple's Screen Time APIs that turns your daily app time into a **pool** you spend in deliberate breaks, with friends who can request and grant each other time.

## How it works

- **Daily pool**: you pick the apps to limit and a daily budget (default 120 min). Outside a break, those apps are shielded.
- **Breaks and downtime**: starting a break lifts the shields for a timed window; when it ends, or the pool is exhausted, the shields return. A `DeviceActivityMonitor` extension enforces this even when the app is closed.
- **Friends**: add friends, see their status, and send **time requests**; approved requests top up the pool. Backed by Firebase Auth, Firestore listeners, and push notifications.

## Architecture

| Target | Role |
|---|---|
| `ScreenTimePool` | SwiftUI app: onboarding, dashboard, friends, time requests, settings. MVVM with `@MainActor` view models, SwiftData for local state. |
| `ScreenTimePoolMonitor` | `DeviceActivityMonitor` extension: applies and clears `ManagedSettingsStore` shields on interval start/end. |
| `ScreenTimePoolShield` | `ShieldConfiguration` extension: custom shield UI. |
| `ScreenTimePoolShieldAction` | `ShieldAction` extension: handles taps on the shield. |
| `firebase/` | Firestore rules and Cloud Functions. |

State is shared between the app and its extensions through an App Group (`group.com.screentimepool.shared`).

## Build

Requires Xcode 16+, an Apple Developer account with the **Family Controls** entitlement, and a physical device (Screen Time APIs do not run in the simulator). Add your `GoogleService-Info.plist` for Firebase.

## Stack

Swift · SwiftUI · SwiftData · FamilyControls / DeviceActivity / ManagedSettings · Firebase Auth, Firestore, Messaging
