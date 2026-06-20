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
                .background(Color(NSColor.controlBackgroundColor))
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
            return targetId == "header:projects" || targetId == "header:areas" || (targetId?.hasPrefix("area:") == true && index == -1)
        }
        return false
    }
    
    func handleOutlineDrop(draggedId: String, targetId: String?, index: Int) {
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
    }
}

func handleDropStrings(_ items: [String], areaId: String?, projectId: String?, store: AppStore) -> Bool {
    var handled = false
    for string in items {
        if string.hasPrefix("task:") {
            let taskId = String(string.dropFirst(5))
            if var task = store.allTasks.first(where: { $0.id == taskId }) {
                task.areaId = areaId
                task.projectId = projectId
                if projectId != nil && areaId == nil {
                    task.areaId = store.allProjects.first(where: { $0.id == projectId })?.areaId
                }
                store.updateTask(task: task)
                handled = true
            }
        } else if string.hasPrefix("project:") {
            let pId = String(string.dropFirst(8))
            if var project = store.allProjects.first(where: { $0.id == pId }) {
                project.areaId = areaId
                store.updateProject(project: project)
                handled = true
            }
        }
    }
    return handled
}


struct InboxView: View {
    @EnvironmentObject var store: AppStore
    @State private var showingCreateTask = false
    @State private var newTaskTitle = ""
    
    var body: some View {
        List {
            if store.inboxTasks.isEmpty {
                Text("Your Inbox is empty! 🎉")
                    .foregroundColor(.secondary)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(store.inboxTasks, id: \.id) { task in
                    TaskRowView(task: task)
                        .listRowSeparator(.visible)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Inbox")
        .toolbar {
            ToolbarItem {
                Button(action: { showingCreateTask = true }) {
                    Label("Add Task", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateTask) {
            CreateTaskSheet(isPresented: $showingCreateTask)
        }
    }
}

struct GroupedTasksView: View {
    @EnvironmentObject var store: AppStore
    let tasks: [Task]
    @State private var selectedItemId: String? = nil
    
    func buildItems() -> [OutlineItem] {
        var items: [OutlineItem] = []
        
        // 1. Orphan Tasks
        let orphanTasks = tasks.filter { $0.projectId == nil && $0.areaId == nil }
        for task in orphanTasks {
            items.append(OutlineItem(id: "task:\(task.id)", title: task.title, icon: nil, itemType: .task(task)))
        }
        
        // 2. Areas
        for area in store.activeAreas {
            let areaTasks = tasks.filter { $0.areaId == area.id && $0.projectId == nil }
            let areaProjects = store.activeProjects.filter { $0.areaId == area.id }
            let projectsWithTasks = areaProjects.filter { p in tasks.contains(where: { $0.projectId == p.id }) }
            
            if !areaTasks.isEmpty || !projectsWithTasks.isEmpty {
                var areaChildren: [OutlineItem] = []
                for task in areaTasks {
                    areaChildren.append(OutlineItem(id: "task:\(task.id)", title: task.title, icon: nil, itemType: .task(task)))
                }
                for project in projectsWithTasks {
                    let projectTasks = tasks.filter { $0.projectId == project.id }
                    var projChildren: [OutlineItem] = []
                    for task in projectTasks {
                        projChildren.append(OutlineItem(id: "task:\(task.id)", title: task.title, icon: nil, itemType: .task(task)))
                    }
                    areaChildren.append(OutlineItem(id: "project:\(project.id)", title: project.title, icon: "circle.circle", itemType: .project(project), children: projChildren))
                }
                items.append(OutlineItem(id: "area:\(area.id)", title: area.title, icon: "square.grid.2x2", itemType: .area(area), children: areaChildren))
            }
        }
        
        // 3. Orphan Projects
        let orphanProjects = store.activeProjects.filter { $0.areaId == nil }
        let orphanProjectsWithTasks = orphanProjects.filter { p in tasks.contains(where: { $0.projectId == p.id }) }
        
        if !orphanProjectsWithTasks.isEmpty {
            let projectsHeader = OutlineItem(id: "header:orphan_projects", title: "Projects", icon: nil, itemType: .header("Projects"))
            var projItems: [OutlineItem] = []
            for project in orphanProjectsWithTasks {
                let projectTasks = tasks.filter { $0.projectId == project.id }
                var projChildren: [OutlineItem] = []
                for task in projectTasks {
                    projChildren.append(OutlineItem(id: "task:\(task.id)", title: task.title, icon: nil, itemType: .task(task)))
                }
                projItems.append(OutlineItem(id: "project:\(project.id)", title: project.title, icon: "circle.circle", itemType: .project(project), children: projChildren))
            }
            projectsHeader.children = projItems
            items.append(projectsHeader)
        }
        
        return items
    }
    
    var body: some View {
        FernOutlineView(
            items: buildItems(),
            selectedItemId: $selectedItemId,
            onMove: { draggedId, targetId, index in
                handleDrop(draggedId: draggedId, targetId: targetId, index: index)
            },
            onValidateMove: { draggedId, targetId, index in
                validateDrop(draggedId: draggedId, targetId: targetId, index: index)
            }
        ) { item in
            GroupedItemView(item: item)
        }
    }
    
    func validateDrop(draggedId: String, targetId: String?, index: Int) -> Bool {
        if draggedId.hasPrefix("task:") {
            return true
        }
        return false
    }
    
    func handleDrop(draggedId: String, targetId: String?, index: Int) {
        if draggedId.hasPrefix("task:") {
            let taskId = String(draggedId.dropFirst(5))
            if var task = store.allTasks.first(where: { $0.id == taskId }) {
                if let target = targetId {
                    if target.hasPrefix("project:") {
                        task.projectId = String(target.dropFirst(8))
                        task.areaId = store.allProjects.first(where: { $0.id == task.projectId })?.areaId
                    } else if target.hasPrefix("area:") {
                        task.projectId = nil
                        task.areaId = String(target.dropFirst(5))
                    } else if target == "header:orphan_projects" {
                        task.projectId = nil
                        task.areaId = nil
                    }
                } else {
                    task.projectId = nil
                    task.areaId = nil
                }
                store.updateTask(task: task)
                
                if index >= 0 {
                    let siblings = tasks.filter { $0.projectId == task.projectId && $0.areaId == task.areaId }
                    if let sourceIndex = siblings.firstIndex(where: { $0.id == taskId }) {
                        store.moveTask(from: IndexSet(integer: sourceIndex), to: index, tasksContext: siblings)
                    }
                }
            }
        }
    }
}

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
        }
    }
}

struct TodayView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        GroupedTasksView(tasks: store.todayTasks)
        .navigationTitle("Today")
        .overlay { if store.todayTasks.isEmpty { Text("Nothing for today!").foregroundColor(.secondary) } }
    }
}

struct UpcomingView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        GroupedTasksView(tasks: store.upcomingTasks)
        .navigationTitle("Upcoming")
        .overlay { if store.upcomingTasks.isEmpty { Text("No upcoming tasks.").foregroundColor(.secondary) } }
    }
}

struct AnytimeView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        GroupedTasksView(tasks: store.anytimeTasks)
        .navigationTitle("Anytime")
        .overlay { if store.anytimeTasks.isEmpty { Text("No anytime tasks.").foregroundColor(.secondary) } }
    }
}

struct SomedayView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        GroupedTasksView(tasks: store.somedayTasks)
        .navigationTitle("Someday")
        .overlay { if store.somedayTasks.isEmpty { Text("No someday tasks.").foregroundColor(.secondary) } }
    }
}

struct LogbookView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        List(store.logbookTasks, id: \.id) { task in TaskRowView(task: task).listRowSeparator(.visible) }
        .listStyle(.plain)
        .navigationTitle("Logbook")
        .overlay { if store.logbookTasks.isEmpty { Text("Logbook is empty.").foregroundColor(.secondary) } }
    }
}

struct CreateTaskSheet: View {
    @EnvironmentObject var store: AppStore
    @Binding var isPresented: Bool
    @State private var newTaskTitle = ""
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("What do you want to do?", text: $newTaskTitle)
            }
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.addTask(title: newTaskTitle)
                        isPresented = false
                    }
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct TaskRowView: View {
    @EnvironmentObject var store: AppStore
    let task: Task
    var showContext: Bool = true
    @State private var showingDetail = false
    
    var subtitle: String? {
        guard showContext else { return nil }
        if let pid = task.projectId, let p = store.allProjects.first(where: { $0.id == pid }) {
            return p.title
        } else if let aid = task.areaId, let a = store.activeAreas.first(where: { $0.id == aid }) {
            return a.title
        }
        return nil
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.secondary)
                .draggable(String("task:\(task.id)"))
                .padding(.trailing, 4)
                
            Button(action: {
                var updated = task
                updated.status = (task.status == .done) ? .todo : .done
                store.updateTask(task: updated)
            }) {
                Image(systemName: task.status == .done ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(task.status == .done ? .blue : .secondary)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 15))
                    .strikethrough(task.status == .done)
                    .foregroundColor(task.status == .done ? .secondary : .primary)
                
                if let sub = subtitle {
                    Text(sub)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            TaskDetailView(task: task)
        }
        .contextMenu {
            if task.isTrashed {
                Button(action: {
                    store.restoreTask(id: task.id)
                }) {
                    Label("Restore Task", systemImage: "arrow.uturn.backward")
                }
            } else {
                Button(role: .destructive, action: {
                    store.deleteTask(id: task.id)
                }) {
                    Label("Trash Task", systemImage: "trash")
                }
            }
        }
    }
}

enum TaskDestination: Hashable {
    case inbox
    case area(String)
    case project(String)
}

struct TaskDetailView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    
    @State private var title: String
    @State private var notes: String
    
    @State private var hasScheduledDate: Bool
    @State private var hasScheduledTime: Bool
    @State private var scheduledDate: Date
    @State private var destination: TaskDestination
    
    var task: Task
    
    init(task: Task) {
        self.task = task
        _title = State(initialValue: task.title)
        _notes = State(initialValue: task.notes)
        
        if let pId = task.projectId {
            _destination = State(initialValue: .project(pId))
        } else if let aId = task.areaId {
            _destination = State(initialValue: .area(aId))
        } else {
            _destination = State(initialValue: .inbox)
        }
        
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let tf = DateFormatter()
        tf.dateFormat = "HH:mm:ss"
        
        if let sd = task.scheduledDate, case let .on(dateStr, timeStr) = sd, let d = df.date(from: dateStr) {
            _hasScheduledDate = State(initialValue: true)
            if let tStr = timeStr, let t = tf.date(from: tStr) {
                _hasScheduledTime = State(initialValue: true)
                let cal = Calendar.current
                var comps = cal.dateComponents([.year, .month, .day], from: d)
                let tComps = cal.dateComponents([.hour, .minute, .second], from: t)
                comps.hour = tComps.hour
                comps.minute = tComps.minute
                comps.second = tComps.second
                _scheduledDate = State(initialValue: cal.date(from: comps) ?? d)
            } else {
                _hasScheduledTime = State(initialValue: false)
                _scheduledDate = State(initialValue: d)
            }
        } else {
            _hasScheduledDate = State(initialValue: false)
            _hasScheduledTime = State(initialValue: false)
            _scheduledDate = State(initialValue: Date())
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...10)
                }
                
                Section("Organisation") {
                    Picker("Destination", selection: $destination) {
                        Text("Inbox").tag(TaskDestination.inbox)
                        
                        let orphans = store.activeProjects.filter { $0.areaId == nil }
                        if !orphans.isEmpty {
                            Divider()
                            ForEach(orphans, id: \.id) { project in
                                Text("Project: \(project.title)").tag(TaskDestination.project(project.id))
                            }
                        }
                        
                        ForEach(store.activeAreas, id: \.id) { area in
                            Divider()
                            Text("Area: \(area.title)").tag(TaskDestination.area(area.id))
                            
                            let areaProjects = store.activeProjects.filter { $0.areaId == area.id }
                            ForEach(areaProjects, id: \.id) { project in
                                Text("   ↳ \(project.title)").tag(TaskDestination.project(project.id))
                            }
                        }
                    }
                }
                
                Section("Scheduling") {
                    Toggle("Schedule Task", isOn: $hasScheduledDate)
                    if hasScheduledDate {
                        Toggle("Set Specific Time", isOn: $hasScheduledTime)
                        if hasScheduledTime {
                            DatePicker("Date & Time", selection: $scheduledDate, displayedComponents: [.date, .hourAndMinute])
                        } else {
                            DatePicker("Date", selection: $scheduledDate, displayedComponents: .date)
                                .datePickerStyle(.graphical)
                        }
                    }
                }
            }
            .navigationTitle("Edit Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let df = DateFormatter()
                        df.dateFormat = "yyyy-MM-dd"
                        let tf = DateFormatter()
                        tf.dateFormat = "HH:mm:ss"
                        
                        var updated = task
                        updated.title = title
                        updated.notes = notes
                        
                        switch destination {
                        case .inbox:
                            updated.projectId = nil
                            updated.areaId = nil
                        case .area(let aId):
                            updated.projectId = nil
                            updated.areaId = aId
                        case .project(let pId):
                            updated.projectId = pId
                            updated.areaId = store.activeProjects.first(where: { $0.id == pId })?.areaId
                        }
                        
                        if hasScheduledDate {
                            updated.scheduledDate = .on(
                                date: df.string(from: scheduledDate),
                                time: hasScheduledTime ? tf.string(from: scheduledDate) : nil
                            )
                        } else {
                            updated.scheduledDate = nil
                        }
                        
                        store.updateTask(task: updated)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .toolbar {
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive, action: {
                        store.deleteTask(id: task.id)
                        dismiss()
                    }) {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    MainContentView()
        .environmentObject(try! AppStore(inMemory: true))
}

struct ProjectDetailView: View {
    @EnvironmentObject var store: AppStore
    var project: Project
    @State private var title: String
    @State private var selectedAreaId: String?
    
    var projectTasks: [Task] {
        store.allTasks.filter { $0.projectId == project.id && !$0.isTrashed }
    }
    
    init(project: Project) {
        self.project = project
        _title = State(initialValue: project.title)
        _selectedAreaId = State(initialValue: project.areaId)
    }
    
    var body: some View {
        List {
            Section {
                TextField("Project Title", text: $title, onCommit: {
                    var updated = project
                    updated.title = title
                    store.updateProject(project: updated)
                })
                .font(.largeTitle.bold())
                
                HStack {
                    Text("Area:")
                        .foregroundColor(.secondary)
                    Picker("", selection: $selectedAreaId) {
                        Text("None").tag(String?.none)
                        ForEach(store.activeAreas, id: \.id) { area in
                            Text(area.title).tag(String?(area.id))
                        }
                    }
                    .labelsHidden()
                    .onChange(of: selectedAreaId) { newAreaId in
                        var updated = project
                        updated.areaId = newAreaId
                        store.updateProject(project: updated)
                    }
                }
            }
            
            Section {
                ForEach(projectTasks, id: \.id) { task in
                    TaskRowView(task: task, showContext: false)
                }
                .onMove { source, destination in
                    store.moveTask(from: source, to: destination, tasksContext: projectTasks)
                }
                
                Button(action: {
                    let task = Task(id: UUID().uuidString, projectId: project.id, areaId: project.areaId, title: "New Task", notes: "", scheduledDate: nil, deadline: nil, estimatedTime: nil, spentTime: nil, status: .todo, isTrashed: false, position: 0.0)
                    do { try store.api.createTask(task: task); store.loadAllData() } catch {}
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("New Task")
                        Spacer()
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .listStyle(.plain)
        .navigationTitle(project.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive, action: {
                    store.deleteProject(id: project.id)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .onChange(of: project.id) { _ in 
            title = project.title
            selectedAreaId = project.areaId 
        }
    }
}

struct AreaDetailView: View {
    @EnvironmentObject var store: AppStore
    var area: Area
    @State private var title: String
    
    var areaProjects: [Project] {
        store.allProjects.filter { $0.areaId == area.id && !$0.isTrashed }
    }
    var areaTasks: [Task] {
        store.allTasks.filter { $0.areaId == area.id && $0.projectId == nil && !$0.isTrashed }
    }
    
    init(area: Area) {
        self.area = area
        _title = State(initialValue: area.title)
    }
    
    var body: some View {
        List {
            Section {
                TextField("Area Title", text: $title, onCommit: {
                    var updated = area
                    updated.title = title
                    store.updateArea(area: updated)
                })
                .font(.largeTitle.bold())
            }
            
            if !areaProjects.isEmpty {
                Section(header: Text("Projects")) {
                    ForEach(areaProjects, id: \.id) { project in
                        NavigationLink(destination: ProjectDetailView(project: project).id(project.id)) {
                            HStack {
                                Image(systemName: "circle.circle")
                                    .foregroundColor(.secondary)
                                Text(project.title)
                                Spacer()
                            }
                        }
                    }
                    .onMove { source, destination in
                        store.moveProject(from: source, to: destination, in: area.id)
                    }
                }
            }
            
            Section(header: Text("Tasks")) {
                ForEach(areaTasks, id: \.id) { task in
                    TaskRowView(task: task, showContext: false)
                }
                .onMove { source, destination in
                    store.moveTask(from: source, to: destination, tasksContext: areaTasks)
                }
                
                HStack(spacing: 20) {
                    Button(action: {
                        store.addProject(title: "New Project", areaId: area.id)
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.dashed")
                            Text("New Project")
                        }
                    }
                    
                    Button(action: {
                        let task = Task(id: UUID().uuidString, projectId: nil, areaId: area.id, title: "New Task", notes: "", scheduledDate: nil, deadline: nil, estimatedTime: nil, spentTime: nil, status: .todo, isTrashed: false, position: 0.0)
                        do { try store.api.createTask(task: task); store.loadAllData() } catch {}
                    }) {
                        HStack {
                            Image(systemName: "plus.square.dashed")
                            Text("New Task")
                        }
                    }
                }
                .foregroundColor(.secondary)
                .buttonStyle(PlainButtonStyle())
            }
        }
        .listStyle(.plain)
        .navigationTitle(area.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive, action: {
                    store.deleteArea(id: area.id)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .onChange(of: area.id) { _ in title = area.title }
    }
}

struct TrashView: View {
    @EnvironmentObject var store: AppStore
    
    var trashedTasks: [Task] {
        store.allTasks.filter { $0.isTrashed }
    }
    
    var trashedProjects: [Project] {
        store.allProjects.filter { $0.isTrashed }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Trash")
                    .font(.largeTitle.bold())
                    .padding(.horizontal)
                    .padding(.top, 20)
                
                Divider().padding(.horizontal)
                
                if trashedProjects.isEmpty && trashedTasks.isEmpty {
                    Text("Trash is empty")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    if !trashedProjects.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Projects")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            ForEach(trashedProjects, id: \.id) { project in
                                HStack {
                                    Image(systemName: "circle.circle")
                                        .foregroundColor(.secondary)
                                    Text(project.title)
                                        .strikethrough()
                                    Spacer()
                                    Button("Restore") {
                                        store.restoreProject(id: project.id)
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                            }
                        }
                        Divider().padding(.horizontal)
                    }
                    
                    if !trashedTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(trashedTasks, id: \.id) { task in
                                TaskRowView(task: task)
                                    .padding(.horizontal)
                                Divider().padding(.leading, 40)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Trash")
    }
}
