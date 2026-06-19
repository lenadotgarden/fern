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
    
    init() {
        // Test de connexion avec Rust !
        do {
            let api = try FernApi.newInMemory()
            
            let task = Task(
                id: UUID().uuidString,
                projectId: nil,
                areaId: nil,
                title: "Hello from Rust Core! 🦀",
                notes: "",
                scheduledDate: nil,
                deadline: nil,
                estimatedTime: nil,
                spentTime: nil,
                status: .todo,
                isTrashed: false
            )
            
            try api.createTask(task: task)
            let inboxTasks = try api.getInboxTasks()
            print("🚀 SUCCÈS ! Connecté à Rust. \(inboxTasks.count) tâche trouvée dans l'Inbox.")
            print("🌿 Titre de la tâche : \(inboxTasks[0].title)")
        } catch {
            print("❌ Erreur Rust : \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Text("Hello fern 🌿")
                .font(.largeTitle)
                .padding()
        }
    }
}
