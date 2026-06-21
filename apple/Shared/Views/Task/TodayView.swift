import SwiftUI
import UniformTypeIdentifiers

struct TodayView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        GroupedTasksView(tasks: store.todayTasks)
        .navigationTitle("Today")
        .overlay { if store.todayTasks.isEmpty { Text("Nothing for today!").foregroundColor(.secondary) } }
    }
}
