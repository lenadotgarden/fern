import SwiftUI
import AppKit

struct FernOutlineView<Content: View>: NSViewRepresentable {
    var items: [OutlineItem]
    @Binding var selectedItemId: String?
    
    let content: (OutlineItem) -> Content
    
    // Drag & Drop handlers
    var onMove: ((_ draggedId: String, _ targetId: String?, _ index: Int) -> Void)?
    var onValidateMove: ((_ draggedId: String, _ targetId: String?, _ index: Int) -> Bool)?
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.documentView = context.coordinator.outlineView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.update(items: items)
        
        // Sync selection
        if let id = selectedItemId {
            if let item = context.coordinator.findItem(by: id),
               let row = context.coordinator.rowForItem(item) {
                if nsView.documentView is NSOutlineView {
                    let outlineView = nsView.documentView as! NSOutlineView
                    if outlineView.selectedRow != row {
                        outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                    }
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
        var parent: FernOutlineView
        var outlineView: NSOutlineView
        var rootItems: [OutlineItem] = []
        
        init(_ parent: FernOutlineView) {
            self.parent = parent
            self.outlineView = NSOutlineView()
            super.init()
            
            // Setup OutlineView
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("MainColumn"))
            outlineView.addTableColumn(column)
            outlineView.outlineTableColumn = column
            outlineView.headerView = nil
            outlineView.style = .sourceList
            outlineView.rowSizeStyle = .custom
            outlineView.rowHeight = 28
            outlineView.backgroundColor = .clear
            
            outlineView.dataSource = self
            outlineView.delegate = self
            
            // Enable Drag and Drop
            outlineView.registerForDraggedTypes([.string])
            outlineView.draggingDestinationFeedbackStyle = .sourceList
        }
        
        func update(items: [OutlineItem]) {
            self.rootItems = items
            outlineView.reloadData()
            outlineView.expandItem(nil, expandChildren: true)
        }
        
        func findItem(by id: String, in items: [OutlineItem]? = nil) -> OutlineItem? {
            let searchItems = items ?? rootItems
            for item in searchItems {
                if item.id == id { return item }
                if let found = findItem(by: id, in: item.children) { return found }
            }
            return nil
        }
        
        func rowForItem(_ item: OutlineItem) -> Int? {
            let row = outlineView.row(forItem: item)
            return row >= 0 ? row : nil
        }
        
        // MARK: - NSOutlineViewDataSource
        
        func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            if let outlineItem = item as? OutlineItem {
                return outlineItem.children.count
            }
            return rootItems.count
        }
        
        func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            if let outlineItem = item as? OutlineItem {
                return outlineItem.children[index]
            }
            return rootItems[index]
        }
        
        func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
            if let outlineItem = item as? OutlineItem {
                return !outlineItem.children.isEmpty
            }
            return false
        }
        
        // MARK: - NSOutlineViewDelegate
        
        func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
            guard let outlineItem = item as? OutlineItem else { return nil }
            
            let identifier = NSUserInterfaceItemIdentifier("OutlineCell")
            var view = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSHostingView<Content>
            
            if view == nil {
                view = NSHostingView(rootView: parent.content(outlineItem))
                view?.identifier = identifier
            } else {
                view?.rootView = parent.content(outlineItem)
            }
            
            // Layout margins or padding
            view?.translatesAutoresizingMaskIntoConstraints = false
            
            let cellView = NSTableCellView()
            if let v = view {
                cellView.addSubview(v)
                NSLayoutConstraint.activate([
                    v.leadingAnchor.constraint(equalTo: cellView.leadingAnchor),
                    v.trailingAnchor.constraint(equalTo: cellView.trailingAnchor),
                    v.topAnchor.constraint(equalTo: cellView.topAnchor),
                    v.bottomAnchor.constraint(equalTo: cellView.bottomAnchor)
                ])
            }
            
            return cellView
        }
        
        func outlineViewSelectionDidChange(_ notification: Notification) {
            let row = outlineView.selectedRow
            if row >= 0, let item = outlineView.item(atRow: row) as? OutlineItem {
                if parent.selectedItemId != item.id {
                    parent.selectedItemId = item.id
                }
            } else {
                if parent.selectedItemId != nil {
                    parent.selectedItemId = nil
                }
            }
        }
        
        // MARK: - Drag and Drop
        
        func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
            guard let outlineItem = item as? OutlineItem else { return nil }
            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setString(outlineItem.id, forType: .string)
            return pasteboardItem
        }
        
        func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
            guard let pasteboardString = info.draggingPasteboard.string(forType: .string) else { return [] }
            let targetItem = item as? OutlineItem
            
            if let validate = parent.onValidateMove {
                if validate(pasteboardString, targetItem?.id, index) {
                    return .move
                } else {
                    return []
                }
            }
            return .move
        }
        
        func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
            guard let pasteboardString = info.draggingPasteboard.string(forType: .string) else { return false }
            
            let targetItem = item as? OutlineItem
            parent.onMove?(pasteboardString, targetItem?.id, index)
            return true
        }
    }
}
