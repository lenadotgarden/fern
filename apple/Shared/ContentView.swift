import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            Text("Select an item in the sidebar")
                .font(.largeTitle)
                .foregroundColor(.secondary)
        }
        .onAppear {
            store.loadAllData()
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        List {
            Section("Views") {
                NavigationLink(destination: InboxView()) {
                    Label("Inbox", systemImage: "tray")
                        .badge(store.inboxTasks.count)
                }
                NavigationLink(destination: TodayView()) {
                    Label("Today", systemImage: "star")
                        .badge(store.todayTasks.count)
                }
                NavigationLink(destination: UpcomingView()) {
                    Label("Upcoming", systemImage: "calendar")
                        .badge(store.upcomingTasks.count)
                }
                NavigationLink(destination: AnytimeView()) {
                    Label("Anytime", systemImage: "tray.2")
                        .badge(store.anytimeTasks.count)
                }
                NavigationLink(destination: SomedayView()) {
                    Label("Someday", systemImage: "archivebox")
                        .badge(store.somedayTasks.count)
                }
                NavigationLink(destination: LogbookView()) {
                    Label("Logbook", systemImage: "book.closed")
                }
            }
            
            Section("Projects") {
                ForEach(store.activeProjects, id: \.id) { project in
                    NavigationLink(destination: ProjectDetailView(project: project)) {
                        Text(project.title)
                    }
                }
                Button(action: {
                    store.addProject(title: "New Project")
                }) {
                    Label("Add Project", systemImage: "plus")
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Section("Areas") {
                ForEach(store.activeAreas, id: \.id) { area in
                    NavigationLink(destination: AreaDetailView(area: area)) {
                        Text(area.title)
                    }
                }
                Button(action: {
                    store.addArea(title: "New Area")
                }) {
                    Label("Add Area", systemImage: "plus")
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Fern")
    }
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
            } else {
                ForEach(store.inboxTasks, id: \.id) { task in
                    TaskRowView(task: task)
                }
            }
        }
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

struct TodayView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        List(store.todayTasks, id: \.id) { task in TaskRowView(task: task) }
        .navigationTitle("Today")
        .overlay { if store.todayTasks.isEmpty { Text("Nothing for today!").foregroundColor(.secondary) } }
    }
}

struct UpcomingView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        List(store.upcomingTasks, id: \.id) { task in TaskRowView(task: task) }
        .navigationTitle("Upcoming")
        .overlay { if store.upcomingTasks.isEmpty { Text("No upcoming tasks.").foregroundColor(.secondary) } }
    }
}

struct AnytimeView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        List(store.anytimeTasks, id: \.id) { task in TaskRowView(task: task) }
        .navigationTitle("Anytime")
        .overlay { if store.anytimeTasks.isEmpty { Text("No anytime tasks.").foregroundColor(.secondary) } }
    }
}

struct SomedayView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        List(store.somedayTasks, id: \.id) { task in TaskRowView(task: task) }
        .navigationTitle("Someday")
        .overlay { if store.somedayTasks.isEmpty { Text("No someday tasks.").foregroundColor(.secondary) } }
    }
}

struct LogbookView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        List(store.logbookTasks, id: \.id) { task in TaskRowView(task: task) }
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
    @State private var showingDetail = false
    
    var body: some View {
        HStack {
            Button(action: {
                var updated = task
                updated.status = (task.status == .done) ? .todo : .done
                store.updateTask(task: updated)
            }) {
                Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.status == .done ? .blue : .secondary)
            }
            .buttonStyle(PlainButtonStyle())
            
            Text(task.title)
                .strikethrough(task.status == .done)
                .foregroundColor(task.status == .done ? .secondary : .primary)
            
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            TaskDetailView(task: task)
        }
    }
}

struct TaskDetailView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    
    @State private var title: String
    @State private var notes: String
    
    @State private var hasScheduledDate: Bool
    @State private var hasScheduledTime: Bool
    @State private var scheduledDate: Date
    @State private var selectedProjectId: String?
    @State private var selectedAreaId: String?
    
    var task: Task
    
    init(task: Task) {
        self.task = task
        _title = State(initialValue: task.title)
        _notes = State(initialValue: task.notes)
        _selectedProjectId = State(initialValue: task.projectId)
        _selectedAreaId = State(initialValue: task.areaId)
        
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
                    Picker("Area", selection: $selectedAreaId) {
                        Text("None").tag(String?.none)
                        ForEach(store.activeAreas, id: \.id) { area in
                            Text(area.title).tag(String?(area.id))
                        }
                    }
                    Picker("Project", selection: $selectedProjectId) {
                        Text("None").tag(String?.none)
                        ForEach(store.activeProjects, id: \.id) { project in
                            Text(project.title).tag(String?(project.id))
                        }
                    }
                }
                
                Section("Scheduling") {
                    Toggle("Schedule Task", isOn: $hasScheduledDate)
                    if hasScheduledDate {
                        Toggle("Set Specific Time", isOn: $hasScheduledTime)
                        DatePicker("Date", selection: $scheduledDate, displayedComponents: hasScheduledTime ? [.date, .hourAndMinute] : .date)
                            .datePickerStyle(.graphical)
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
                        updated.projectId = selectedProjectId
                        updated.areaId = selectedAreaId
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
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    ContentView()
        .environmentObject(try! AppStore(inMemory: true))
}

struct ProjectDetailView: View {
    @EnvironmentObject var store: AppStore
    var project: Project
    @State private var title: String
    
    var projectTasks: [Task] {
        store.allTasks.filter { $0.projectId == project.id && !$0.isTrashed }
    }
    
    init(project: Project) {
        self.project = project
        _title = State(initialValue: project.title)
    }
    
    var body: some View {
        Form {
            Section("Project Title") {
                TextField("Title", text: $title, onCommit: {
                    var updated = project
                    updated.title = title
                    store.updateProject(project: updated)
                })
            }
            Section("Tasks") {
                ForEach(projectTasks, id: \.id) { task in
                    TaskRowView(task: task)
                }
                Button("Add Task to Project") {
                    let task = Task(id: UUID().uuidString, projectId: project.id, areaId: project.areaId, title: "New Task", notes: "", scheduledDate: nil, deadline: nil, estimatedTime: nil, spentTime: nil, status: .todo, isTrashed: false)
                    do { try store.api.createTask(task: task); store.loadAllData() } catch {}
                }
            }
        }
        .navigationTitle(project.title)
        .onChange(of: project.id) { _ in title = project.title }
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
        Form {
            Section("Area Title") {
                TextField("Title", text: $title, onCommit: {
                    var updated = area
                    updated.title = title
                    store.updateArea(area: updated)
                })
            }
            Section("Projects") {
                ForEach(areaProjects, id: \.id) { project in
                    NavigationLink(destination: ProjectDetailView(project: project)) {
                        Text(project.title)
                    }
                }
                Button("Add Project") { store.addProject(title: "New Project", areaId: area.id) }
            }
            Section("Direct Tasks") {
                ForEach(areaTasks, id: \.id) { task in
                    TaskRowView(task: task)
                }
            }
        }
        .navigationTitle(area.title)
        .onChange(of: area.id) { _ in title = area.title }
    }
}
