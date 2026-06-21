import SwiftUI
import UniformTypeIdentifiers

struct GroupedTasksView: View {
    @EnvironmentObject var store: AppStore
    let tasks: [Task]
    @State private var selectedItemId: String? = nil
    
    func buildItems() -> [OutlineItem] {
        var items: [OutlineItem] = []
        
        // 1. Orphan Tasks
        let orphanTasks = tasks.filter { $0.projectId == nil && $0.areaId == nil }
        for task in orphanTasks {
            items.append(OutlineItem(id: "task:\(task.id)", title: task.title, icon: nil, itemType: .task(task)))
        }
        
        // 2. Areas
        for area in store.activeAreas {
            let areaTasks = tasks.filter { $0.areaId == area.id && $0.projectId == nil }
            let areaProjects = store.activeProjects.filter { $0.areaId == area.id }
            let projectsWithTasks = areaProjects.filter { p in tasks.contains(where: { $0.projectId == p.id }) }
            
            if !areaTasks.isEmpty || !projectsWithTasks.isEmpty {
                var areaChildren: [OutlineItem] = []
                for task in areaTasks {
                    areaChildren.append(OutlineItem(id: "task:\(task.id)", title: task.title, icon: nil, itemType: .task(task)))
                }
                for project in projectsWithTasks {
                    let projectTasks = tasks.filter { $0.projectId == project.id }
                    var projChildren: [OutlineItem] = []
                    for task in projectTasks {
                        projChildren.append(OutlineItem(id: "task:\(task.id)", title: task.title, icon: nil, itemType: .task(task)))
                    }
                    areaChildren.append(OutlineItem(id: "project:\(project.id)", title: project.title, icon: "circle.circle", itemType: .project(project), children: projChildren))
                }
                items.append(OutlineItem(id: "area:\(area.id)", title: area.title, icon: "square.grid.2x2", itemType: .area(area), children: areaChildren))
            }
        }
        
        // 3. Orphan Projects
        let orphanProjects = store.activeProjects.filter { $0.areaId == nil }
        let orphanProjectsWithTasks = orphanProjects.filter { p in tasks.contains(where: { $0.projectId == p.id }) }
        
        if !orphanProjectsWithTasks.isEmpty {
            let projectsHeader = OutlineItem(id: "header:orphan_projects", title: "Projects", icon: nil, itemType: .header("Projects"))
            var projItems: [OutlineItem] = []
            for project in orphanProjectsWithTasks {
                let projectTasks = tasks.filter { $0.projectId == project.id }
                var projChildren: [OutlineItem] = []
                for task in projectTasks {
                    projChildren.append(OutlineItem(id: "task:\(task.id)", title: task.title, icon: nil, itemType: .task(task)))
                }
                projItems.append(OutlineItem(id: "project:\(project.id)", title: project.title, icon: "circle.circle", itemType: .project(project), children: projChildren))
            }
            projectsHeader.children = projItems
            items.append(projectsHeader)
        }
        
        return items
    }
    
    var body: some View {
        FernOutlineView(
            items: buildItems(),
            selectedItemId: $selectedItemId,
            onMove: { draggedId, targetId, index in
                handleDrop(draggedId: draggedId, targetId: targetId, index: index)
            },
            onValidateMove: { draggedId, targetId, index in
                validateDrop(draggedId: draggedId, targetId: targetId, index: index)
            }
        ) { item in
            GroupedItemView(item: item)
        }
    }
    
    func validateDrop(draggedId: String, targetId: String?, index: Int) -> Bool {
        if draggedId.hasPrefix("task:") {
            return true
        }
        return false
    }
    
    func handleDrop(draggedId: String, targetId: String?, index: Int) {
        if draggedId.hasPrefix("task:") {
            let taskId = String(draggedId.dropFirst(5))
            if var task = store.allTasks.first(where: { $0.id == taskId }) {
                var groupChanged = false
                if let target = targetId {
                    if target.hasPrefix("project:") {
                        let targetProjectId = String(target.dropFirst(8))
                        if task.projectId != targetProjectId {
                            task.projectId = targetProjectId
                            task.areaId = store.allProjects.first(where: { $0.id == task.projectId })?.areaId
                            groupChanged = true
                        }
                    } else if target.hasPrefix("area:") {
                        let targetAreaId = String(target.dropFirst(5))
                        if task.areaId != targetAreaId || task.projectId != nil {
                            task.projectId = nil
                            task.areaId = targetAreaId
                            groupChanged = true
                        }
                    } else if target == "header:orphan_projects" {
                        if task.projectId != nil || task.areaId != nil {
                            task.projectId = nil
                            task.areaId = nil
                            groupChanged = true
                        }
                    }
                } else {
                    if task.projectId != nil || task.areaId != nil {
                        task.projectId = nil
                        task.areaId = nil
                        groupChanged = true
                    }
                }
                
                if groupChanged {
                    store.updateTask(task: task)
                }
                
                if index >= 0 {
                    let siblings = tasks.filter { $0.projectId == task.projectId && $0.areaId == task.areaId && $0.id != taskId }
                    
                    if groupChanged {
                        // Cross-group move, calculate position directly based on insertion index
                        let prevPos = index > 0 && index <= siblings.count ? siblings[index - 1].position : nil
                        let nextPos = index < siblings.count ? siblings[index].position : nil
                        
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
                        
                        task.position = newPos
                        store.updateTask(task: task)
                    } else {
                        // Same group move
                        let originalSiblings = tasks.filter { $0.projectId == task.projectId && $0.areaId == task.areaId }
                        if let sourceIndex = originalSiblings.firstIndex(where: { $0.id == taskId }) {
                            store.moveTask(from: IndexSet(integer: sourceIndex), to: index, tasksContext: originalSiblings)
                        }
                    }
                }
            }
        }
    }
}
