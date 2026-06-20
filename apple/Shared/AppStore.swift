import Foundation
import SwiftUI
import Combine

@MainActor
class AppStore: ObservableObject {
    let api: FernApi
    @Published var tasks: [Task] = []
    
    init(inMemory: Bool = false) throws {
        if inMemory {
            self.api = try FernApi.newInMemory()
        } else {
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let dbPath = documentsURL.appendingPathComponent("fern.sqlite").path
            self.api = try FernApi(path: dbPath)
        }
    }
    
    func loadInbox() {
        do {
            let fetchedTasks = try api.getInboxTasks()
            self.tasks = fetchedTasks
        } catch {
            print("❌ Failed to load inbox tasks: \(error)")
        }
    }
    
    func addTask(title: String, notes: String = "") {
        let task = Task(
            id: UUID().uuidString,
            projectId: nil,
            areaId: nil,
            title: title,
            notes: notes,
            scheduledDate: nil,
            deadline: nil,
            estimatedTime: nil,
            spentTime: nil,
            status: .todo,
            isTrashed: false
        )
        do {
            try api.createTask(task: task)
            loadInbox() // Rafraîchit l'interface !
        } catch {
            print("❌ Failed to create task: \(error)")
        }
    }
}

extension Task {
    static func mock() -> Task {
        return Task(
            id: UUID().uuidString,
            projectId: nil,
            areaId: nil,
            title: "Test SwiftUI Task",
            notes: "",
            scheduledDate: nil,
            deadline: nil,
            estimatedTime: nil,
            spentTime: nil,
            status: .todo,
            isTrashed: false
        )
    }
}
