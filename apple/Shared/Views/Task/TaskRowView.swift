import SwiftUI
import UniformTypeIdentifiers

struct TaskRowView: View {
    @EnvironmentObject var store: AppStore
    let task: Task
    var showContext: Bool = true
    @State private var showingDetail = false
    
    var subtitle: String? {
        guard showContext else { return nil }
        if let pid = task.projectId, let p = store.allProjects.first(where: { $0.id == pid }) {
            return p.title
        } else if let aid = task.areaId, let a = store.activeAreas.first(where: { $0.id == aid }) {
            return a.title
        }
        return nil
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: {
                var updated = task
                updated.status = (task.status == .done) ? .todo : .done
                store.updateTask(task: updated)
            }) {
                Image(systemName: task.status == .done ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(task.status == .done ? .blue : .secondary)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 15))
                    .strikethrough(task.status == .done)
                    .foregroundColor(task.status == .done ? .secondary : .primary)
                
                if let sub = subtitle {
                    Text(sub)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .draggable("task:\(task.id)")
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            TaskDetailView(task: task)
        }
        .contextMenu {
            if task.isTrashed {
                Button(action: {
                    store.restoreTask(id: task.id)
                }) {
                    Label("Restore Task", systemImage: "arrow.uturn.backward")
                }
            } else {
                Button(role: .destructive, action: {
                    store.deleteTask(id: task.id)
                }) {
                    Label("Trash Task", systemImage: "trash")
                }
            }
        }
    }
}
