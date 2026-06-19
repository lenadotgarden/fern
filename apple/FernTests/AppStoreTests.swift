import XCTest
@testable import Fern

@MainActor
final class AppStoreTests: XCTestCase {

    func testStoreInitialization() throws {
        // Arrange & Act
        // On initialise le store avec une DB en mémoire pour éviter d'écrire sur le vrai disque
        let store = try AppStore(inMemory: true)
        
        // Assert
        XCTAssertNotNil(store.api, "The Rust API must be initialized")
        XCTAssertTrue(store.tasks.isEmpty, "On a fresh DB, the tasks list should be empty")
    }
    
    func testStoreLoadsInboxTasks() throws {
        // Arrange
        let store = try AppStore(inMemory: true)
        let task = Task(
            id: UUID().uuidString,
            projectId: nil,
            areaId: nil,
            title: "Test SwiftUI Task",
            notes: "",
            scheduledDate: nil,
            deadline: nil,
            estimatedTime: nil,
            spentTime: nil,
            status: .todo,
            isTrashed: false
        )
        
        // On contourne le store pour insérer directement via l'API pour préparer le test
        try store.api.createTask(task: task)
        
        // Act
        store.loadInbox()
        
        // Assert
        XCTAssertEqual(store.tasks.count, 1)
        XCTAssertEqual(store.tasks.first?.title, "Test SwiftUI Task")
    }
}
