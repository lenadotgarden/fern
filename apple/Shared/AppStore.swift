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
            isTrashed: false,
            position: 0.0
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
            isArchived: false,
            position: 0.0
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
    
    func moveArea(from source: IndexSet, to destination: Int) {
        guard let sourceIndex = source.first else { return }
        let movedArea = activeAreas[sourceIndex]
        var newAreas = activeAreas
        newAreas.move(fromOffsets: source, toOffset: destination)
        
        guard let newIndex = newAreas.firstIndex(where: { $0.id == movedArea.id }) else { return }
        
        let prevPos = newIndex > 0 ? newAreas[newIndex - 1].position : nil
        let nextPos = newIndex < newAreas.count - 1 ? newAreas[newIndex + 1].position : nil
        
        let newPos: Double
        if let p = prevPos, let n = nextPos {
            newPos = (p + n) / 2.0
        } else if let p = prevPos {
            newPos = p + 1.0
        } else if let n = nextPos {
            newPos = n - 1.0
        } else {
            newPos = 0.0
        }
        
        do {
            try api.updateAreaPosition(id: movedArea.id, newPosition: newPos)
            loadAllData()
        } catch {
            print("❌ Failed to move area: \(error)")
        }
    }

    func moveProject(from source: IndexSet, to destination: Int, in areaId: String?) {
        let projects = activeProjects.filter { $0.areaId == areaId }
        guard let sourceIndex = source.first else { return }
        let movedProject = projects[sourceIndex]
        
        var newProjects = projects
        newProjects.move(fromOffsets: source, toOffset: destination)
        
        guard let newIndex = newProjects.firstIndex(where: { $0.id == movedProject.id }) else { return }
        
        let prevPos = newIndex > 0 ? newProjects[newIndex - 1].position : nil
        let nextPos = newIndex < newProjects.count - 1 ? newProjects[newIndex + 1].position : nil
        
        let newPos: Double
        if let p = prevPos, let n = nextPos {
            newPos = (p + n) / 2.0
        } else if let p = prevPos {
            newPos = p + 1.0
        } else if let n = nextPos {
            newPos = n - 1.0
        } else {
            newPos = 0.0
        }
        
        do {
            try api.updateProjectPosition(id: movedProject.id, newPosition: newPos)
            loadAllData()
        } catch {
            print("❌ Failed to move project: \(error)")
        }
    }

    func moveTask(from source: IndexSet, to destination: Int, tasksContext: [Task]) {
        guard let sourceIndex = source.first else { return }
        let movedTask = tasksContext[sourceIndex]
        
        var newTasks = tasksContext
        newTasks.move(fromOffsets: source, toOffset: destination)
        
        guard let newIndex = newTasks.firstIndex(where: { $0.id == movedTask.id }) else { return }
        
        let prevPos = newIndex > 0 ? newTasks[newIndex - 1].position : nil
        let nextPos = newIndex < newTasks.count - 1 ? newTasks[newIndex + 1].position : nil
        
        let newPos: Double
        if let p = prevPos, let n = nextPos {
            newPos = (p + n) / 2.0
        } else if let p = prevPos {
            newPos = p + 1.0
        } else if let n = nextPos {
            newPos = n - 1.0
        } else {
            newPos = 0.0
        }
        
        do {
            try api.updateTaskPosition(id: movedTask.id, newPosition: newPos)
            loadAllData()
        } catch {
            print("❌ Failed to move task: \(error)")
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
            isTrashed: false,
            position: 0.0
        )
    }
}
