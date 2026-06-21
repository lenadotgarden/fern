import SwiftUI
import UniformTypeIdentifiers

func handleDropStrings(_ items: [String], areaId: String?, projectId: String?, store: AppStore) -> Bool {
    var handled = false
    for string in items {
        if string.hasPrefix("task:") {
            let taskId = String(string.dropFirst(5))
            if var task = store.allTasks.first(where: { $0.id == taskId }) {
                task.areaId = areaId
                task.projectId = projectId
                if projectId != nil && areaId == nil {
                    task.areaId = store.allProjects.first(where: { $0.id == projectId })?.areaId
                }
                store.updateTask(task: task)
                handled = true
            }
        } else if string.hasPrefix("project:") {
            let pId = String(string.dropFirst(8))
            if var project = store.allProjects.first(where: { $0.id == pId }) {
                project.areaId = areaId
                store.updateProject(project: project)
                handled = true
            }
        }
    }
    return handled
}
