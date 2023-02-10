//Adds a clear button to the `CanvasBoard` view that calls the `clearCanvas` method when it is tapped
//The `clearCanvas` method calls the `clear` method on the `CanvasView` to clear the lines from the canvas

import SwiftUI

struct CanvasBoard: View {
  @State private var strokeColor = Color.black
  @State private var strokeWidth: CGFloat = 1

  var body: some View {
    VStack {
      HStack {
        Button(action: {
          clearCanvas()
        }) {
          Image(systemName: "clear")
            .imageScale(.large)
        }

        ColorPicker("Stroke Color", selection: $strokeColor)
          .padding()

        Slider(value: $strokeWidth, in: 1...20)
          .padding()
      }
      .padding()

      CanvasView(strokeColor: strokeColor, strokeWidth: strokeWidth)
    }
  }

  private func clearCanvas() {
    canvasView.clear()
  }

  private var canvasView: CanvasView {
    return CanvasView(strokeColor: strokeColor, strokeWidth: strokeWidth)
  }
}

struct CanvasView: View {
  @State private var lines = [Line]()
  let strokeColor: Color
  let strokeWidth: CGFloat

  var body: some View {
    GeometryReader { geometry in
      Path { path in
        for line in lines {
          path.move(to: line.start)
          path.addLine(to: line.end)
        }
      }
      .stroke(strokeColor, lineWidth: strokeWidth)
      .background(Color.white)
      .gesture(
        DragGesture()
          .onChanged { value in
            lines.append(Line(start: value.startLocation, end: value.location))
          }
      )
    }
  }

  func clear() {
    lines = []
  }
}

struct Line {
  let start: CGPoint
  let end: CGPoint
}

struct CanvasBoard_Previews: PreviewProvider {
  static var previews: some View {
    CanvasBoard()
  }
}

//Save and load drawings

struct CanvasBoard: View {
  @State private var strokeColor = Color.black
  @State private var strokeWidth: CGFloat = 1
  @State private var showSaveSheet = false
  @State private var showOpenSheet = false
  @State private var saveName = ""

  var body: some View {
    VStack {
      HStack {
        Button(action: {
          clearCanvas()
        }) {
          Image(systemName: "clear")
            .imageScale(.large)
        }

        ColorPicker("Stroke Color", selection: $strokeColor)
          .padding()

        Slider(value: $strokeWidth, in: 1...20)
          .padding()

        Button(action: {
          showSaveSheet = true
        }) {
          Image(systemName: "square.and.arrow.up")
            .imageScale(.large)
        }
        .sheet(isPresented: $showSaveSheet) {
          SaveSheet(showSaveSheet: $showSaveSheet, saveName: $saveName, canvasView: canvasView)
        }

        Button(action: {
          showOpenSheet = true
        }) {
          Image(systemName: "square.and.arrow.down")
            .imageScale(.large)
        }
        .sheet(isPresented: $showOpenSheet) {
          OpenSheet(showOpenSheet: $showOpenSheet, canvasView: canvasView)
        }
      }
      .padding()

      CanvasView(strokeColor: strokeColor, strokeWidth: strokeWidth)
    }
  }

  private func clearCanvas() {
    canvasView.clear()
  }

  private var canvasView: CanvasView {
    return CanvasView(strokeColor: strokeColor, strokeWidth: strokeWidth)
  }
}

struct CanvasView: View {
  @State private var lines = [Line]()
  let strokeColor: Color
  let strokeWidth: CGFloat

  var body: some View {
    GeometryReader { geometry in
      Path { path in
        for line in lines {
          path.move(to: line.start)
          path.addLine(to: line.end)
        }
      }
      .stroke(strokeColor, lineWidth: strokeWidth)
      .background(Color.white)
      .gesture(
        DragGesture()
          .onChanged { value in
            lines.append(Line(start: value.startLocation, end: value.location))
          }
      )
    }
  }

  func clear() {
    lines = []
  }

  func save(name: String) {
    let encodedLines = try! JSONEncoder().encode(lines)
    UserDefaults.standard.set(encodedLines, forKey: name)
  }

  func load(name: String) {
    guard let encodedLines = UserDefaults.standard.data(forKey: name) else { return }
    lines = try! JSONDecoder().decode([Line].self, from: encodedLines)
  }
}

struct Line {
  let start: CGPoint
  let end: CGPoint
}

struct SaveSheet: View {
  @Binding var showSaveSheet: Bool
  @Binding var saveName: String
  let canvasView: CanvasView

  var body: some View {
    NavigationView {
      VStack {
        TextField("Save As", text: $saveName)
        Button(action: {
          canvasView.save(name: saveName)
          showSaveSheet = false
        }) {
          Text("Save")
        }
      }
      .navigationBarTitle("Save Drawing")
    }
  }
}

struct OpenSheet: View {
  @Binding var showOpenSheet: Bool
  let canvasView: CanvasView

  var body: some View {
    NavigationView {
      List {
        ForEach(UserDefaults.standard.dictionaryRepresentation().keys, id: \.self) { key in
          Button(action: {
            canvasView.load(name: key)
            showOpenSheet = false
          }) {
            Text(key)
          }
        }
      }
      .navigationBarTitle("Open Drawing")
    }
  }
}

struct CanvasBoard_Previews: PreviewProvider {
  static var previews: some View {
    CanvasBoard()
  }
}




