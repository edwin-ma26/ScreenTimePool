//
//  ShieldConfigurationExtension.swift
//  ScreenTimePoolShield
//
//  Created by Edwin Ma on 2/11/26.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private let appGroupIdentifier = "group.com.screentimepool.shared"

    private var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        buildConfiguration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        buildConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        buildConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        buildConfiguration()
    }

    private func buildConfiguration() -> ShieldConfiguration {
        let defaults = appGroupDefaults
        let phase = defaults?.string(forKey: "sessionPhase") ?? "idle"
        let poolSeconds = defaults?.integer(forKey: "remainingPoolSeconds") ?? 0

        let poolHours = poolSeconds / 3600
        let poolMins = (poolSeconds % 3600) / 60

        let poolText: String
        if poolHours > 0 {
            poolText = "\(poolHours)h \(poolMins)m"
        } else {
            poolText = "\(poolMins)m"
        }

        let title: String
        let subtitle: String

        switch phase {
        case "exhausted":
            title = "Pool Exhausted"
            subtitle = "You've used all your screen time for today. Request more time from a friend."

        case "downtime":
            title = "Break Time"
            subtitle = "\(poolText) pool remaining. Open ScreenTimePool to check your break timer."

        default:
            title = "Start a Session"
            subtitle = "\(poolText) pool remaining. Open ScreenTimePool to start."
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterial,
            backgroundColor: UIColor.systemBackground,
            title: ShieldConfiguration.Label(text: title, color: .label),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: .secondaryLabel),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Close", color: .white),
            primaryButtonBackgroundColor: .systemBlue
        )
    }
}
