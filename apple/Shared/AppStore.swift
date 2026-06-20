import Foundation
import SwiftUI
import Combine

@MainActor
class AppStore: ObservableObject {
    let api: FernApi
    @Published var inboxTasks: [Task] = []
    @Published var todayTasks: [Task] = []
    @Published var upcomingTasks: [Task] = []
    @Published var anytimeTasks: [Task] = []
    @Published var somedayTasks: [Task] = []
    @Published var logbookTasks: [Task] = []
    
    init(inMemory: Bool = false) throws {
        if inMemory {
            self.api = try FernApi.newInMemory()
        } else {
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let dbPath = documentsURL.appendingPathComponent("fern.sqlite").path
            self.api = try FernApi(path: dbPath)
        }
    }
    
    func loadAllData() {
        do {
            self.inboxTasks = try api.getInboxTasks()
            self.todayTasks = try api.getTodayTasks()
            self.upcomingTasks = try api.getUpcomingTasks()
            self.anytimeTasks = try api.getAnytimeTasks()
            self.somedayTasks = try api.getSomedayTasks()
            self.logbookTasks = try api.getLogbookTasks()
        } catch {
            print("❌ Failed to load tasks: \(error)")
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
            loadAllData() // Rafraîchit l'interface !
        } catch {
            print("❌ Failed to create task: \(error)")
        }
    }
    
    func updateTask(task: Task) {
        do {
            try api.updateTask(task: task)
            loadAllData()
        } catch {
            print("❌ Failed to update task: \(error)")
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
