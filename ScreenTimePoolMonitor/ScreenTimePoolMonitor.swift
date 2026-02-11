import Foundation
import DeviceActivity
import ManagedSettings
import FamilyControls

class ScreenTimePoolMonitor: DeviceActivityMonitor {

    private let appGroupIdentifier = "group.com.screentimepool.shared"

    private var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    private let idleStore = ManagedSettingsStore(named: .init("idle"))
    private let downtimeStore = ManagedSettingsStore(named: .init("downtime"))
    private let exhaustedStore = ManagedSettingsStore(named: .init("exhausted"))

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        switch activity.rawValue {
        case "com.screentimepool.session":
            // Session started — ensure shields are removed (apps accessible)
            idleStore.clearAllSettings()
            downtimeStore.clearAllSettings()
            exhaustedStore.clearAllSettings()

        case "com.screentimepool.downtime":
            // Downtime started — apply shields to block selected apps
            applyShields(to: downtimeStore)

        default:
            break
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        guard let defaults = appGroupDefaults else { return }

        // If a bonus session is active, don't interfere — the main app manages shields
        let isBonusSession = defaults.bool(forKey: "isBonusSession")
        let currentPhase = defaults.string(forKey: "sessionPhase")
        if isBonusSession && currentPhase == "active" {
            return
        }

        switch activity.rawValue {
        case "com.screentimepool.session":
            // Session ended — check if pool exhausted or enter downtime
            let poolSeconds = defaults.integer(forKey: "remainingPoolSeconds")
            if poolSeconds <= 0 {
                applyShields(to: exhaustedStore)
                defaults.set("exhausted", forKey: "sessionPhase")
            } else {
                applyShields(to: downtimeStore)
                defaults.set("downtime", forKey: "sessionPhase")
            }

        case "com.screentimepool.downtime":
            // Downtime ended — remove downtime shields
            downtimeStore.clearAllSettings()
            let poolSeconds = defaults.integer(forKey: "remainingPoolSeconds")
            if poolSeconds <= 0 {
                applyShields(to: exhaustedStore)
                defaults.set("exhausted", forKey: "sessionPhase")
            } else {
                applyShields(to: idleStore)
                defaults.set("idle", forKey: "sessionPhase")
            }

        default:
            break
        }

        defaults.set(Date(), forKey: "lastUpdated")
    }

    // MARK: - Shield Application

    private func applyShields(to store: ManagedSettingsStore) {
        guard let data = appGroupDefaults?.data(forKey: "familyActivitySelectionData"),
              let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return
        }

        if !selection.applicationTokens.isEmpty {
            store.shield.applications = selection.applicationTokens
        }
        if !selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
        }
        if !selection.webDomainTokens.isEmpty {
            store.shield.webDomains = selection.webDomainTokens
        }
    }
}
