
import SwiftUI

struct ImageOCR: View {
    @State private var words: [Text] = []
    @State private var progress: Double = 0
    @State private var image: Image?
    @State private var error: Error?

    var body: some View {
        VStack {
            if let image = image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if let error = error {
                Text(error.localizedDescription)
            }
            ProgressView(value: progress)
            List(words) { word in
                Text(word.string)
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            self.detectText()
        }
    }

    func detectText() {
        guard let url = url else { return }
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                self.error = error
                return
            }
            guard let requestResults = request.results as? [VNRecognizedTextObservation] else {
                fatalError("Wrong result type")
            }
            let words = requestResults.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            self.words = words
        }
        request.preferBackgroundProcessing = true
        // Other setup...
        let imageRequestHandler = VNImageRequestHandler(url: url)
        do {
            try imageRequestHandler.perform([request])
            self.image = Image(url: url)
        } catch {
            self.error = error
        }
    }
}


