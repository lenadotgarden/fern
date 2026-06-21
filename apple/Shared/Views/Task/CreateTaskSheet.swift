import SwiftUI
import UniformTypeIdentifiers

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
