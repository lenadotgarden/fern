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
                    HStack {
                        Image(systemName: "circle")
                            .foregroundColor(.secondary)
                        Text(task.title)
                    }
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

#Preview {
    ContentView()
        .environmentObject(try! AppStore(inMemory: true))
}
