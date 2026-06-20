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
                NavigationLink(destination: Text("Today View")) {
                    Label("Today", systemImage: "star")
                }
                NavigationLink(destination: Text("Upcoming View")) {
                    Label("Upcoming", systemImage: "calendar")
                }
                NavigationLink(destination: Text("Anytime View")) {
                    Label("Anytime", systemImage: "tray.2")
                }
                NavigationLink(destination: Text("Someday View")) {
                    Label("Someday", systemImage: "archivebox")
                }
                NavigationLink(destination: Text("Logbook View")) {
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
                Button(action: {
                    showingCreateTask = true
                }) {
                    Label("Add Task", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateTask) {
            NavigationStack {
                Form {
                    TextField("What do you want to do?", text: $newTaskTitle)
                }
                .navigationTitle("New Task")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingCreateTask = false
                            newTaskTitle = ""
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            store.addTask(title: newTaskTitle)
                            showingCreateTask = false
                            newTaskTitle = ""
                        }
                        .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
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
                updated.status = .logbook
                store.updateTask(task: updated)
            }) {
                Image(systemName: task.status == .logbook ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.status == .logbook ? .blue : .secondary)
            }
            .buttonStyle(PlainButtonStyle())
            
            Text(task.title)
                .strikethrough(task.status == .logbook)
                .foregroundColor(task.status == .logbook ? .secondary : .primary)
            
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
            .navigationBarTitleDisplayMode(.inline)
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
