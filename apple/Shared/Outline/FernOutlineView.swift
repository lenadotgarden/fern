import SwiftUI
import AppKit

struct FernOutlineView: NSViewRepresentable {
    var items: [OutlineItem]
    var onSelectionChanged: ((OutlineItem?) -> Void)?
    
    // Drag & Drop handlers
    var onMove: ((_ draggedId: String, _ targetId: String?, _ index: Int) -> Void)?
    
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
            var view = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
            
            if view == nil {
                view = NSTableCellView()
                view?.identifier = identifier
                
                let imageView = NSImageView()
                imageView.translatesAutoresizingMaskIntoConstraints = false
                view?.addSubview(imageView)
                view?.imageView = imageView
                
                let textField = NSTextField(labelWithString: "")
                textField.translatesAutoresizingMaskIntoConstraints = false
                view?.addSubview(textField)
                view?.textField = textField
                
                NSLayoutConstraint.activate([
                    imageView.leadingAnchor.constraint(equalTo: view!.leadingAnchor, constant: 4),
                    imageView.centerYAnchor.constraint(equalTo: view!.centerYAnchor),
                    imageView.widthAnchor.constraint(equalToConstant: 16),
                    imageView.heightAnchor.constraint(equalToConstant: 16),
                    
                    textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 8),
                    textField.trailingAnchor.constraint(equalTo: view!.trailingAnchor, constant: -4),
                    textField.centerYAnchor.constraint(equalTo: view!.centerYAnchor)
                ])
            }
            
            view?.textField?.stringValue = outlineItem.title
            
            if let iconName = outlineItem.icon {
                view?.imageView?.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
            } else {
                view?.imageView?.image = nil
            }
            
            // Adjust styling based on type
            if case .header = outlineItem.itemType {
                view?.textField?.font = .systemFont(ofSize: 11, weight: .semibold)
                view?.textField?.textColor = .secondaryLabelColor
            } else {
                view?.textField?.font = .systemFont(ofSize: 13, weight: .regular)
                view?.textField?.textColor = .labelColor
            }
            
            return view
        }
        
        func outlineViewSelectionDidChange(_ notification: Notification) {
            let row = outlineView.selectedRow
            if row >= 0, let item = outlineView.item(atRow: row) as? OutlineItem {
                parent.onSelectionChanged?(item)
            } else {
                parent.onSelectionChanged?(nil)
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
            // For now, accept all moves
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
