//
//  FernApp.swift
//  Fern
//
//  Created by Léna Le Poulichet on 19/06/2026.
//

import Foundation
import SwiftUI

@main
struct FernApp: App {
    @StateObject private var store: AppStore
    
    init() {
        // Initialize the real persistent SQLite database for the app
        do {
            let appStore = try AppStore(inMemory: false)
            _store = StateObject(wrappedValue: appStore)
        } catch {
            fatalError("❌ Failed to initialize the Rust database: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainContentView()
                .environmentObject(store)
        }
    }
}
