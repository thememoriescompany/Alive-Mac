
import SwiftUI

struct IndexContext {
    let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
}

struct Text: Hashable, Codable {
    let string: String
    let confidence: Float
}

struct SearchableRepresentation {
    let text: [Text]
    let dates: Set<Date>
}

protocol IndexItem: Hashable {
    func getSearchableRepresentation(
        indexContext: IndexContext,
        completion: @escaping (SearchableRepresentation) -> Void
    )
}



