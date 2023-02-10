
class ThreadSafeObjectProvider<ObjectType> {
    init(objectProvider: @escaping () -> ObjectType, maxCachedObjects: Int = 100) {
        self.objectProvider = objectProvider
        guard maxCachedObjects > 0 else { return }
        for _ in 0..<maxCachedObjects {
            cache.append(CacheItem(object: objectProvider()))
        }
    }

    func provideObject(_ completion: @escaping (ObjectType) -> Void) {
        var cacheItem: CacheItem? = nil
        queue.sync {
            for item in cache where item.isAvailable {
                cacheItem = item
                item.isAvailable = false
                break
            }
        }
        if let cacheItem = cacheItem {
            completion(cacheItem.object)
            cacheItem.isAvailable = true
        } else {
            assertionFailure("Unexpectedly no available cached objects.")
            completion(objectProvider())
        }
    }

    private let objectProvider: () -> ObjectType
    private var cache = [CacheItem]()

    private let queue = DispatchQueue(label: "com.example.object-provider-queue")

    private class CacheItem {
        init(object: ObjectType) {
            self.object = object
            isAvailable = true
        }

        let object: ObjectType
        var isAvailable: Bool
    }
}


struct ImageLoader: View {
    @State private var isLoading = false
    @State private var image: Image?

    var body: some View {
        if isLoading {
            ProgressView()
        } else if let image = image {
            Image(uiImage: image.uiImage)
                .resizable()
        } else {
            Button("Load Image") {
                isLoading = true
                DispatchQueue.global().async {
                    let image = loadImage()
                    DispatchQueue.main.async {
                        self.image = image
                        isLoading = false
                    }
                }
            }
        }
    }

    func loadImage() -> Image {
        // Load image logic...
    }
}

//This shows handling loading state, async loading of data, and updating UI on the main queue.

struct CustomModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.largeTitle)
            .foregroundColor(.red)
    }
}

extension View {
    func customModified() -> some View {
        self.modifier(CustomModifier())
    }
}

struct ContentView: View {
    var body: some View {
        Text("Hello")
            .customModified()
    }
}

//This shows creating and using a custom SwiftUI view modifier to easily reuse styling logic.

struct ThemeSelector: View {
    @AppStorage("selectedTheme") private var selectedTheme = 0

    var body: some View {
        Picker("Theme", selection: $selectedTheme) {
            Text("Light").tag(0)
            Text("Dark").tag(1)
        }
        .pickerStyle(SegmentedPickerStyle())
        .onChange(of: selectedTheme) { newValue in
            // Update theme...
        }
    }
}

//This shows using AppStorage to persist a selection and reacting to changes.


