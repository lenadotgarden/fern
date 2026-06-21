import SwiftUI
import UniformTypeIdentifiers

struct AreaDetailView: View {
    @EnvironmentObject var store: AppStore
    var area: Area
    @State private var title: String
    @State private var selectedItemId: String?
    
    var areaProjects: [Project] {
        store.allProjects.filter { $0.areaId == area.id && !$0.isTrashed }
    }
    var areaTasks: [Task] {
        store.allTasks.filter { $0.areaId == area.id && $0.projectId == nil && !$0.isTrashed }
    }
    
    init(area: Area) {
        self.area = area
        _title = State(initialValue: area.title)
    }
    
    func buildItems() -> [OutlineItem] {
        var items: [OutlineItem] = []
        
        if !areaProjects.isEmpty {
            let projectsHeader = OutlineItem(id: "header:projects", title: "Projects", icon: nil, itemType: .header("Projects"))
            var projItems: [OutlineItem] = []
            for project in areaProjects {
                projItems.append(OutlineItem(id: "project:\(project.id)", title: project.title, icon: "circle.circle", itemType: .project(project)))
            }
            projectsHeader.children = projItems
            items.append(projectsHeader)
        }
        
        let tasksHeader = OutlineItem(id: "header:tasks", title: "Tasks", icon: nil, itemType: .header("Tasks"))
        var taskItems: [OutlineItem] = []
        for task in areaTasks {
            taskItems.append(OutlineItem(id: "task:\(task.id)", title: task.title, icon: nil, itemType: .task(task)))
        }
        tasksHeader.children = taskItems
        items.append(tasksHeader)
        
        return items
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Area Title", text: $title, onCommit: {
                var updated = area
                updated.title = title
                store.updateArea(area: updated)
            })
            .font(.largeTitle.bold())
            .textFieldStyle(PlainTextFieldStyle())
            .padding()
            
            FernOutlineView(
                items: buildItems(),
                selectedItemId: $selectedItemId,
                onMove: { draggedId, targetId, index in
                    if draggedId.hasPrefix("task:"), index >= 0 {
                        let taskId = String(draggedId.dropFirst(5))
                        if let sourceIndex = areaTasks.firstIndex(where: { $0.id == taskId }) {
                            store.moveTask(from: IndexSet(integer: sourceIndex), to: index, tasksContext: areaTasks)
                        }
                    } else if draggedId.hasPrefix("project:"), index >= 0 {
                        let pId = String(draggedId.dropFirst(8))
                        if let sourceIndex = areaProjects.firstIndex(where: { $0.id == pId }) {
                            store.moveProject(from: IndexSet(integer: sourceIndex), to: index, in: area.id)
                        }
                    }
                },
                onValidateMove: { draggedId, targetId, index in
                    if draggedId.hasPrefix("task:") {
                        return targetId == "header:tasks" || targetId?.hasPrefix("task:") == true
                    } else if draggedId.hasPrefix("project:") {
                        return targetId == "header:projects" || targetId?.hasPrefix("project:") == true
                    }
                    return false
                }
            ) { item in
                GroupedItemView(item: item)
            }
            
            HStack(spacing: 20) {
                Button(action: {
                    store.addProject(title: "New Project", areaId: area.id)
                }) {
                    HStack {
                        Image(systemName: "plus.circle.dashed")
                        Text("New Project")
                    }
                }
                
                Button(action: {
                    let task = Task(id: UUID().uuidString, projectId: nil, areaId: area.id, title: "New Task", notes: "", scheduledDate: nil, deadline: nil, estimatedTime: nil, spentTime: nil, status: .todo, isTrashed: false, position: 0.0)
                    do { try store.api.createTask(task: task); store.loadAllData() } catch {}
                }) {
                    HStack {
                        Image(systemName: "plus.square.dashed")
                        Text("New Task")
                    }
                }
            }
            .foregroundColor(.secondary)
            .buttonStyle(PlainButtonStyle())
            .padding()
        }
        .navigationTitle(area.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive, action: {
                    store.deleteArea(id: area.id)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .onChange(of: area.id) { _ in title = area.title }
    }
}
