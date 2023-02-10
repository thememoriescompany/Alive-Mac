
import SwiftUI

class ImageWordsCache {
    static let shared = ImageWordsCache()

    @State private var cache: [String: [Text]] = [:]

    func read(for image: Image) -> [Text]? {
        cache[image.cacheKey]
    }

    func save(words: [Text], for image: Image) {
        cache[image.cacheKey] = words
        // Save to disk...
    }

    func clear() {
        cache = [:]
        // Clear disk cache...
    }
}