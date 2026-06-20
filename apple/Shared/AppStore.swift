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
    
    @Published var activeAreas: [Area] = []
    @Published var activeProjects: [Project] = []
    
    @Published var allTasks: [Task] = []
    @Published var allProjects: [Project] = []
    
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
            self.activeAreas = try api.getActiveAreas()
            self.activeProjects = try api.getAnytimeProjects()
            
            self.allTasks = try api.getAllTasks()
            self.allProjects = try api.getAllProjects()
        } catch {
            print("❌ Failed to load data: \(error)")
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
    
    func addProject(title: String, areaId: String? = nil) {
        let project = Project(
            id: UUID().uuidString,
            areaId: areaId,
            title: title,
            notes: "",
            scheduledDate: nil,
            deadline: nil,
            status: .todo,
            isTrashed: false
        )
        do {
            try api.createProject(project: project)
            loadAllData()
        } catch {
            print("❌ Failed to create project: \(error)")
        }
    }
    
    func updateProject(project: Project) {
        do {
            try api.updateProject(project: project)
            loadAllData()
        } catch {
            print("❌ Failed to update project: \(error)")
        }
    }
    
    func addArea(title: String) {
        let area = Area(
            id: UUID().uuidString,
            title: title,
            notes: "",
            isArchived: false
        )
        do {
            try api.createArea(area: area)
            loadAllData()
        } catch {
            print("❌ Failed to create area: \(error)")
        }
    }
    
    func updateArea(area: Area) {
        do {
            try api.updateArea(area: area)
            loadAllData()
        } catch {
            print("❌ Failed to update area: \(error)")
        }
    }
    func deleteTask(id: String) {
        do {
            try api.trashTask(id: id)
            loadAllData()
        } catch {
            print("❌ Failed to delete task: \(error)")
        }
    }
    
    func deleteProject(id: String) {
        do {
            try api.trashProject(id: id)
            loadAllData()
        } catch {
            print("❌ Failed to delete project: \(error)")
        }
    }
    
    func restoreTask(id: String) {
        do {
            try api.restoreTask(id: id)
            loadAllData()
        } catch {
            print("❌ Failed to restore task: \(error)")
        }
    }
    
    func restoreProject(id: String) {
        do {
            try api.restoreProject(id: id)
            loadAllData()
        } catch {
            print("❌ Failed to restore project: \(error)")
        }
    }
    
    func deleteArea(id: String) {
        do {
            try api.deleteArea(id: id)
            loadAllData()
        } catch {
            print("❌ Failed to delete area: \(error)")
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
