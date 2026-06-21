import XCTest
@testable import Fern

@MainActor
final class AppStoreTests: XCTestCase {

    func testStoreInitialization() throws {
        // Arrange & Act
        // Initialize the store with an in-memory DB to avoid writing to the real disk
        let store = try AppStore(inMemory: true)
        
        // Assert
        XCTAssertNotNil(store.api, "The Rust API must be initialized")
        XCTAssertTrue(store.inboxTasks.isEmpty, "On a fresh DB, the tasks list should be empty")
    }
    
    func testStoreLoadsInboxTasks() throws {
        // Arrange
        let store = try AppStore(inMemory: true)
        let task = Fern.Task.mock()
        
        // Bypass the store to insert directly via the API to prepare the test
        try store.api.createTask(task: task)
        
        // Act
        store.loadAllData()
        
        // Assert
        XCTAssertEqual(store.inboxTasks.count, 1)
        XCTAssertEqual(store.inboxTasks.first?.title, "Test SwiftUI Task")
    }
}
