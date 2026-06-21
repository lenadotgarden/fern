import SwiftUI
import UniformTypeIdentifiers

struct ProjectDetailView: View {
    @EnvironmentObject var store: AppStore
    var project: Project
    @State private var title: String
    @State private var selectedAreaId: String?
    @State private var selectedItemId: String?
    
    var projectTasks: [Task] {
        store.allTasks.filter { $0.projectId == project.id && !$0.isTrashed }
    }
    
    init(project: Project) {
        self.project = project
        _title = State(initialValue: project.title)
        _selectedAreaId = State(initialValue: project.areaId)
    }
    
    func buildItems() -> [OutlineItem] {
        return projectTasks.map { task in
            OutlineItem(id: "task:\(task.id)", title: task.title, icon: nil, itemType: .task(task))
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Project Title", text: $title, onCommit: {
                    var updated = project
                    updated.title = title
                    store.updateProject(project: updated)
                })
                .font(.largeTitle.bold())
                .textFieldStyle(PlainTextFieldStyle())
                
                HStack {
                    Text("Area:")
                        .foregroundColor(.secondary)
                    Picker("", selection: $selectedAreaId) {
                        Text("None").tag(String?.none)
                        ForEach(store.activeAreas, id: \.id) { area in
                            Text(area.title).tag(String?(area.id))
                        }
                    }
                    .labelsHidden()
                    .onChange(of: selectedAreaId) { newAreaId in
                        var updated = project
                        updated.areaId = newAreaId
                        store.updateProject(project: updated)
                    }
                }
            }
            .padding()
            
            FernOutlineView(
                items: buildItems(),
                selectedItemId: $selectedItemId,
                onMove: { draggedId, targetId, index in
                    if draggedId.hasPrefix("task:"), index >= 0 {
                        let taskId = String(draggedId.dropFirst(5))
                        if let sourceIndex = projectTasks.firstIndex(where: { $0.id == taskId }) {
                            store.moveTask(from: IndexSet(integer: sourceIndex), to: index, tasksContext: projectTasks)
                        }
                    }
                },
                onValidateMove: { draggedId, targetId, index in
                    return draggedId.hasPrefix("task:")
                }
            ) { item in
                GroupedItemView(item: item)
            }
            
            Button(action: {
                let task = Task(id: UUID().uuidString, projectId: project.id, areaId: project.areaId, title: "New Task", notes: "", scheduledDate: nil, deadline: nil, estimatedTime: nil, spentTime: nil, status: .todo, isTrashed: false, position: 0.0)
                do { try store.api.createTask(task: task); store.loadAllData() } catch {}
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text("New Task")
                    Spacer()
                }
                .foregroundColor(.secondary)
                .padding()
            }
            .buttonStyle(PlainButtonStyle())
        }
        .navigationTitle(project.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive, action: {
                    store.deleteProject(id: project.id)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .onChange(of: project.id) { _ in 
            title = project.title
            selectedAreaId = project.areaId 
        }
    }
}
