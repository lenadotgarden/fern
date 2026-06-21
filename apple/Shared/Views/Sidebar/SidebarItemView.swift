import SwiftUI
import UniformTypeIdentifiers

struct SidebarItemView: View {
    let item: OutlineItem
    
    var isHeader: Bool {
        if case .header = item.itemType { return true }
        return false
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if let iconName = item.icon {
                Image(systemName: iconName)
                    .frame(width: 16, height: 16)
                    .foregroundColor(isHeader ? .secondary : .accentColor)
            }
            Text(item.title)
                .font(isHeader ? .system(size: 11, weight: .semibold) : .system(size: 13))
                .foregroundColor(isHeader ? .secondary : .primary)
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .draggable(item.id)
    }
}
