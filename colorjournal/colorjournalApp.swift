//
//  HabitualityApp.swift
//  Habituality
//
//  Created by Justin Hanneman on 12/30/24.
//

import SwiftUI
import Security

@main
struct HabitualityApp: App {
    init() {
        // Clear old Google Sign-In keychain entries before any Google SDK code runs
        clearAllGoogleKeychainEntries()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
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
