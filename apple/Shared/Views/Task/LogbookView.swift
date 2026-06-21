import SwiftUI
import UniformTypeIdentifiers

struct LogbookView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        List(store.logbookTasks, id: \.id) { task in TaskRowView(task: task).listRowSeparator(.visible) }
        .listStyle(.plain)
        .navigationTitle("Logbook")
        .overlay { if store.logbookTasks.isEmpty { Text("Logbook is empty.").foregroundColor(.secondary) } }
    }
}
