//
//  HabitualityApp.swift
//  Habituality
//
//  Created by Justin Hanneman on 12/30/24.
//

import SwiftUI
import Security

enum AppTheme: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

@main
struct HabitualityApp: App {
    @AppStorage("appTheme") private var appTheme: String = AppTheme.system.rawValue

    init() {
        // Clear old Google Sign-In keychain entries before any Google SDK code runs
        clearAllGoogleKeychainEntries()
    }

    private var selectedTheme: AppTheme {
        AppTheme(rawValue: appTheme) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(selectedTheme.colorScheme)
        }
    }

    private func clearAllGoogleKeychainEntries() {
        // Delete ALL generic passwords (includes Google auth tokens)
        let genericQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword
        ]
        SecItemDelete(genericQuery as CFDictionary)

        // Delete ALL internet passwords
        let internetQuery: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword
        ]
        SecItemDelete(internetQuery as CFDictionary)
    }
}
