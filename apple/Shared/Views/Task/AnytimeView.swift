import SwiftUI
import UniformTypeIdentifiers

struct AnytimeView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        GroupedTasksView(tasks: store.anytimeTasks)
        .navigationTitle("Anytime")
        .overlay { if store.anytimeTasks.isEmpty { Text("No anytime tasks.").foregroundColor(.secondary) } }
    }
}
