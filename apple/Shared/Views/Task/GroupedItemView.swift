import SwiftUI
import UniformTypeIdentifiers

struct GroupedItemView: View {
    let item: OutlineItem
    @EnvironmentObject var store: AppStore
    
    var isHeader: Bool {
        if case .header = item.itemType { return true }
        return false
    }
    
    var body: some View {
        if case .task(let task) = item.itemType {
            TaskRowView(task: task, showContext: false)
                .padding(.vertical, 2)
        } else {
            HStack(spacing: 8) {
                if let iconName = item.icon {
                    Image(systemName: iconName)
                        .frame(width: 16, height: 16)
                        .foregroundColor(isHeader ? .secondary : .accentColor)
                }
                Text(item.title)
                    .font(isHeader ? .system(size: 11, weight: .semibold) : .system(size: 13, weight: .semibold))
                    .foregroundColor(isHeader ? .secondary : .primary)
                Spacer()
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .draggable(item.id)
        }
    }
}
