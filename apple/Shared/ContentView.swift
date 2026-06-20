import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            Text("Select an item in the sidebar")
                .font(.largeTitle)
                .foregroundColor(.secondary)
        }
        .onAppear {
            store.loadAllData()
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        List {
            Section("Views") {
                NavigationLink(destination: InboxView()) {
                    Label("Inbox", systemImage: "tray")
                        .badge(store.inboxTasks.count)
                }
                NavigationLink(destination: TodayView()) {
                    Label("Today", systemImage: "star")
                        .badge(store.todayTasks.count)
                }
                NavigationLink(destination: UpcomingView()) {
                    Label("Upcoming", systemImage: "calendar")
                        .badge(store.upcomingTasks.count)
                }
                NavigationLink(destination: AnytimeView()) {
                    Label("Anytime", systemImage: "tray.2")
                        .badge(store.anytimeTasks.count)
                }
                NavigationLink(destination: SomedayView()) {
                    Label("Someday", systemImage: "archivebox")
                        .badge(store.somedayTasks.count)
                }
                NavigationLink(destination: LogbookView()) {
                    Label("Logbook", systemImage: "book.closed")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Fern")
    }
}

struct InboxView: View {
    @EnvironmentObject var store: AppStore
    @State private var showingCreateTask = false
    @State private var newTaskTitle = ""
    
    var body: some View {
        List {
            if store.inboxTasks.isEmpty {
                Text("Your Inbox is empty! 🎉")
                    .foregroundColor(.secondary)
            } else {
                ForEach(store.inboxTasks, id: \.id) { task in
                    TaskRowView(task: task)
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

struct TodayView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        List(store.todayTasks, id: \.id) { task in TaskRowView(task: task) }
        .navigationTitle("Today")
        .overlay { if store.todayTasks.isEmpty { Text("Nothing for today!").foregroundColor(.secondary) } }
    }
}

struct UpcomingView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        List(store.upcomingTasks, id: \.id) { task in TaskRowView(task: task) }
        .navigationTitle("Upcoming")
        .overlay { if store.upcomingTasks.isEmpty { Text("No upcoming tasks.").foregroundColor(.secondary) } }
    }
}

struct AnytimeView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        List(store.anytimeTasks, id: \.id) { task in TaskRowView(task: task) }
        .navigationTitle("Anytime")
        .overlay { if store.anytimeTasks.isEmpty { Text("No anytime tasks.").foregroundColor(.secondary) } }
    }
}

struct SomedayView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        List(store.somedayTasks, id: \.id) { task in TaskRowView(task: task) }
        .navigationTitle("Someday")
        .overlay { if store.somedayTasks.isEmpty { Text("No someday tasks.").foregroundColor(.secondary) } }
    }
}

struct LogbookView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        List(store.logbookTasks, id: \.id) { task in TaskRowView(task: task) }
        .navigationTitle("Logbook")
        .overlay { if store.logbookTasks.isEmpty { Text("Logbook is empty.").foregroundColor(.secondary) } }
    }
}

struct CreateTaskSheet: View {
    @EnvironmentObject var store: AppStore
    @Binding var isPresented: Bool
    @State private var newTaskTitle = ""
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("What do you want to do?", text: $newTaskTitle)
            }
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.addTask(title: newTaskTitle)
                        isPresented = false
                    }
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct TaskRowView: View {
    @EnvironmentObject var store: AppStore
    let task: Task
    @State private var showingDetail = false
    
    var body: some View {
        HStack {
            Button(action: {
                var updated = task
                updated.status = .done
                store.updateTask(task: updated)
            }) {
                Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.status == .done ? .blue : .secondary)
            }
            .buttonStyle(PlainButtonStyle())
            
            Text(task.title)
                .strikethrough(task.status == .done)
                .foregroundColor(task.status == .done ? .secondary : .primary)
            
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            TaskDetailView(task: task)
        }
    }
}

struct TaskDetailView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    
    @State private var title: String
    @State private var notes: String
    
    var task: Task
    
    init(task: Task) {
        self.task = task
        _title = State(initialValue: task.title)
        _notes = State(initialValue: task.notes)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...10)
                }
            }
            .navigationTitle("Edit Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = task
                        updated.title = title
                        updated.notes = notes
                        store.updateTask(task: updated)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    ContentView()
        .environmentObject(try! AppStore(inMemory: true))
}
