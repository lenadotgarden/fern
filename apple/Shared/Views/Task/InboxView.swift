import SwiftUI
import UniformTypeIdentifiers

struct InboxView: View {
    @EnvironmentObject var store: AppStore
    @State private var showingCreateTask = false
    @State private var selectedItemId: String?
    
    func buildItems() -> [OutlineItem] {
        return store.inboxTasks.map { task in
            OutlineItem(id: "task:\(task.id)", title: task.title, icon: nil, itemType: .task(task))
        }
    }
    
    var body: some View {
        VStack {
            if store.inboxTasks.isEmpty {
                Text("Your Inbox is empty! 🎉")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                FernOutlineView(
                    items: buildItems(),
                    selectedItemId: $selectedItemId,
                    onMove: { draggedId, targetId, index in
                        if draggedId.hasPrefix("task:"), index >= 0 {
                            let taskId = String(draggedId.dropFirst(5))
                            if let sourceIndex = store.inboxTasks.firstIndex(where: { $0.id == taskId }) {
                                store.moveTask(from: IndexSet(integer: sourceIndex), to: index, tasksContext: store.inboxTasks)
                            }
                        }
                    },
                    onValidateMove: { draggedId, targetId, index in
                        return draggedId.hasPrefix("task:")
                    }
                ) { item in
                    GroupedItemView(item: item)
                }
            }
        }
        .navigationTitle("Inbox")
        .toolbar {
            ToolbarItem {
                Button(action: { showingCreateTask = true }) {
                    Label("Add Task", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateTask) {
            CreateTaskSheet(isPresented: $showingCreateTask)
        }
    }
}
