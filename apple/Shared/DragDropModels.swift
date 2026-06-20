import SwiftUI
import UniformTypeIdentifiers
import CoreTransferable

struct FernItem: Transferable, Codable {
    let id: String
    let type: String // "task" or "project"
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}
