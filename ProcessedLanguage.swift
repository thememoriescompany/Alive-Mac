
// The language representation of an item in the index.
// Stored for debugging purposes
// Output from OCR
// Individual normalized words and their frequencies
// Original words when different from the lemmas

import SwiftUI

struct ProcessedText {
    let recognizedText: [[Text]]
    let wordFrequencies: [String: Int]
    let originalWords: [String: Int]
}




