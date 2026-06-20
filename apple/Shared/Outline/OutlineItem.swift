import SwiftUI
import AppKit

enum OutlineItemType: Equatable {
    case inbox, today, upcoming, anytime, someday, logbook, trash
    case header(String)
    case area(Area)
    case project(Project)
    case task(Task)
}

class OutlineItem: NSObject {
    let id: String
    let title: String
    let icon: String?
    let itemType: OutlineItemType
    var children: [OutlineItem]
    
    init(id: String, title: String, icon: String?, itemType: OutlineItemType, children: [OutlineItem] = []) {
        self.id = id
        self.title = title
        self.icon = icon
        self.itemType = itemType
        self.children = children
    }
}
