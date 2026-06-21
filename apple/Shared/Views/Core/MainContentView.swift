import SwiftUI
import UniformTypeIdentifiers

struct MainContentView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedItemId: String? = "view:today"
    
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                FernOutlineView(
                    items: buildSidebarItems(),
                    selectedItemId: $selectedItemId,
                    isNavigationEnabled: true,
                    onMove: { draggedId, targetId, index in
                        handleOutlineDrop(draggedId: draggedId, targetId: targetId, index: index)
                    },
                    onValidateMove: { draggedId, targetId, index in
                        validateOutlineDrop(draggedId: draggedId, targetId: targetId, index: index)
                    }
                ) { item in
                    SidebarItemView(item: item)
                }
                
                Divider()
                
                HStack {
                    Button(action: { store.addArea(title: "New Area") }) {
                        Label("New Area", systemImage: "plus.square.dashed")
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    Button(action: { store.addProject(title: "New Project") }) {
                        Label("New Project", systemImage: "plus.circle.dashed")
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
#if os(macOS)
                .background(Color(NSColor.controlBackgroundColor))
#else
                .background(Color(UIColor.systemBackground))
#endif
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
        } detail: {
            detailView(for: selectedItemId)
        }
        .onAppear {
            store.loadAllData()
        }
    }
    
    func buildSidebarItems() -> [OutlineItem] {
        var items: [OutlineItem] = []
        
        let fernHeader = OutlineItem(id: "header:fern", title: "Fern", icon: nil, itemType: .header("Fern"), children: [
            OutlineItem(id: "view:inbox", title: "Inbox", icon: "tray", itemType: .inbox),
            OutlineItem(id: "view:today", title: "Today", icon: "star", itemType: .today),
            OutlineItem(id: "view:upcoming", title: "Upcoming", icon: "calendar", itemType: .upcoming),
            OutlineItem(id: "view:anytime", title: "Anytime", icon: "tray.2", itemType: .anytime),
            OutlineItem(id: "view:someday", title: "Someday", icon: "archivebox", itemType: .someday),
            OutlineItem(id: "view:logbook", title: "Logbook", icon: "book.closed", itemType: .logbook),
            OutlineItem(id: "view:trash", title: "Trash", icon: "trash", itemType: .trash)
        ])
        items.append(fernHeader)
        
        let areasHeader = OutlineItem(id: "header:areas", title: "Areas", icon: nil, itemType: .header("Areas"), children: store.activeAreas.map { area in
            let areaProjects = store.activeProjects.filter { $0.areaId == area.id }
            let projectItems = areaProjects.map { project in
                OutlineItem(id: "project:\(project.id)", title: project.title, icon: "circle.circle", itemType: .project(project))
            }
            return OutlineItem(id: "area:\(area.id)", title: area.title, icon: "square.grid.2x2", itemType: .area(area), children: projectItems)
        })
        items.append(areasHeader)
        
        let orphanProjects = store.activeProjects.filter { $0.areaId == nil }
        if !orphanProjects.isEmpty {
            let projectsHeader = OutlineItem(id: "header:projects", title: "Projects", icon: nil, itemType: .header("Projects"), children: orphanProjects.map { project in
                OutlineItem(id: "project:\(project.id)", title: project.title, icon: "circle.circle", itemType: .project(project))
            })
            items.append(projectsHeader)
        }
        
        return items
    }
    
    func validateOutlineDrop(draggedId: String, targetId: String?, index: Int) -> Bool {
        if draggedId.hasPrefix("area:") {
            // Areas can only be reordered within the Areas header
            return targetId == "header:areas" && index >= 0
        } else if draggedId.hasPrefix("project:") {
            // Projects can be moved to an Area, or to the Projects header, or reordered within them
            return targetId == "header:projects" || targetId == "header:areas" || (targetId?.hasPrefix("area:") == true && index >= -1)
        } else if draggedId.hasPrefix("task:") {
            // Tasks can be dropped onto projects, areas, or base views (Inbox, Today, etc.)
            if let target = targetId {
                if target.hasPrefix("project:") || target.hasPrefix("area:") { return true }
                if target.hasPrefix("view:") { return true }
            }
        }
        return false
    }
    
    func handleOutlineDrop(draggedId: String, targetId: String?, index: Int) {
        if draggedId.hasPrefix("task:") {
            let taskId = String(draggedId.dropFirst(5))
            if var task = store.allTasks.first(where: { $0.id == taskId }) {
                if let target = targetId {
                    if target.hasPrefix("project:") {
                        task.projectId = String(target.dropFirst(8))
                        task.areaId = store.allProjects.first(where: { $0.id == task.projectId })?.areaId
                        store.updateTask(task: task)
                    } else if target.hasPrefix("area:") {
                        task.projectId = nil
                        task.areaId = String(target.dropFirst(5))
                        store.updateTask(task: task)
                    } else if target.hasPrefix("view:") {
                        let viewName = String(target.dropFirst(5))
                        if viewName == "inbox" {
                            task.projectId = nil
                            task.areaId = nil
                            task.scheduledDate = nil
                            store.updateTask(task: task)
                        } else if viewName == "trash" {
                            store.deleteTask(id: task.id)
                        } else if viewName == "someday" {
                            task.scheduledDate = .someday
                            store.updateTask(task: task)
                        } else if viewName == "anytime" {
                            task.scheduledDate = nil
                            store.updateTask(task: task)
                        } else if viewName == "today" {
                            let df = DateFormatter()
                            df.dateFormat = "yyyy-MM-dd"
                            task.scheduledDate = .on(date: df.string(from: Date()), time: nil)
                            store.updateTask(task: task)
                        }
                    }
                }
            }
            return
        }
        
        if draggedId.hasPrefix("area:") {
            if targetId == "header:areas" && index >= 0 {
                let aId = String(draggedId.dropFirst(5))
                if let sourceIndex = store.activeAreas.firstIndex(where: { $0.id == aId }) {
                    store.moveArea(from: IndexSet(integer: sourceIndex), to: index)
                }
            }
        } else if draggedId.hasPrefix("project:") {
            let pId = String(draggedId.dropFirst(8))
            if var project = store.allProjects.first(where: { $0.id == pId }) {
                if let target = targetId {
                    if target.hasPrefix("area:") {
                        project.areaId = String(target.dropFirst(5))
                        store.updateProject(project: project)
                    } else if target == "header:areas" {
                        // Handled by reorder if needed, but for now just prevent weird behavior
                    } else if target.hasPrefix("header:projects") {
                        project.areaId = nil
                        store.updateProject(project: project)
                    }
                } else {
                    project.areaId = nil
                    store.updateProject(project: project)
                }
            }
        }
    }
    
    @ViewBuilder
    func detailView(for id: String?) -> some View {
        if let id = id {
            if id == "view:inbox" { InboxView() }
            else if id == "view:today" { TodayView() }
            else if id == "view:upcoming" { UpcomingView() }
            else if id == "view:anytime" { AnytimeView() }
            else if id == "view:someday" { SomedayView() }
            else if id == "view:logbook" { LogbookView() }
            else if id == "view:trash" { TrashView() }
            else if id.hasPrefix("area:") {
                if let area = store.activeAreas.first(where: { $0.id == String(id.dropFirst(5)) }) {
                    AreaDetailView(area: area)
                } else { Text("Area not found").foregroundColor(.secondary) }
            }
            else if id.hasPrefix("project:") {
                if let project = store.activeProjects.first(where: { $0.id == String(id.dropFirst(8)) }) {
                    ProjectDetailView(project: project)
                } else { Text("Project not found").foregroundColor(.secondary) }
            }
            else { Text("Select an item").font(.largeTitle).foregroundColor(.secondary) }
        } else {
            Text("Select an item in the sidebar")
                .font(.largeTitle)
                .foregroundColor(.secondary)
        }
    }
}
