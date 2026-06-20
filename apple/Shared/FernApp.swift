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
        // On initialise la vraie base de données SQLite persistante pour l'app
        do {
            let appStore = try AppStore(inMemory: false)
            _store = StateObject(wrappedValue: appStore)
        } catch {
            fatalError("❌ Impossible d'initialiser la base de données Rust : \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainContentView()
                .environmentObject(store)
        }
    }
}
