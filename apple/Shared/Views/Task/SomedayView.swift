import SwiftUI
import UniformTypeIdentifiers

struct SomedayView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        GroupedTasksView(tasks: store.somedayTasks)
        .navigationTitle("Someday")
        .overlay { if store.somedayTasks.isEmpty { Text("No someday tasks.").foregroundColor(.secondary) } }
    }
}
