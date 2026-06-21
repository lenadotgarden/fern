import SwiftUI
import UniformTypeIdentifiers

struct TrashView: View {
    @EnvironmentObject var store: AppStore
    
    var trashedTasks: [Task] {
        store.allTasks.filter { $0.isTrashed }
    }
    
    var trashedProjects: [Project] {
        store.allProjects.filter { $0.isTrashed }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Trash")
                    .font(.largeTitle.bold())
                    .padding(.horizontal)
                    .padding(.top, 20)
                
                Divider().padding(.horizontal)
                
                if trashedProjects.isEmpty && trashedTasks.isEmpty {
                    Text("Trash is empty")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    if !trashedProjects.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Projects")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            ForEach(trashedProjects, id: \.id) { project in
                                HStack {
                                    Image(systemName: "circle.circle")
                                        .foregroundColor(.secondary)
                                    Text(project.title)
                                        .strikethrough()
                                    Spacer()
                                    Button("Restore") {
                                        store.restoreProject(id: project.id)
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                            }
                        }
                        Divider().padding(.horizontal)
                    }
                    
                    if !trashedTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(trashedTasks, id: \.id) { task in
                                TaskRowView(task: task)
                                    .padding(.horizontal)
                                Divider().padding(.leading, 40)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Trash")
    }
}
