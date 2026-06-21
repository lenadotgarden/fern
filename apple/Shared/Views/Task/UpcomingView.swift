import SwiftUI
import UniformTypeIdentifiers

struct UpcomingView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        GroupedTasksView(tasks: store.upcomingTasks)
        .navigationTitle("Upcoming")
        .overlay { if store.upcomingTasks.isEmpty { Text("No upcoming tasks.").foregroundColor(.secondary) } }
    }
}
