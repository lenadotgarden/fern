import Foundation
import SwiftUI
import Combine

@MainActor
class AppStore: ObservableObject {
    let api: FernApi
    @Published var tasks: [Task] = []
    
    init(inMemory: Bool = false) throws {
        if inMemory {
            self.api = try FernApi.newInMemory()
        } else {
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let dbPath = documentsURL.appendingPathComponent("fern.sqlite").path
            self.api = try FernApi(path: dbPath)
        }
    }
    
    func loadInbox() {
        do {
            let fetchedTasks = try api.getInboxTasks()
            self.tasks = fetchedTasks
        } catch {
            print("❌ Failed to load inbox tasks: \(error)")
        }
    }
}
