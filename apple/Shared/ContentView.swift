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
            store.loadInbox()
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
                        .badge(store.tasks.count)
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
    
    var body: some View {
        List {
            if store.tasks.isEmpty {
                Text("Your Inbox is empty! 🎉")
                    .foregroundColor(.secondary)
            } else {
                ForEach(store.tasks, id: \.id) { task in
                    HStack {
                        Image(systemName: "circle")
                            .foregroundColor(.secondary)
                        Text(task.title)
                    }
                }
            }
        }
        .navigationTitle("Inbox")
    }
}

#Preview {
    ContentView()
        .environmentObject(try! AppStore(inMemory: true))
}
