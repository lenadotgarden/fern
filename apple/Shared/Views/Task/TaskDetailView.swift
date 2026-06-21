import SwiftUI
import UniformTypeIdentifiers

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
