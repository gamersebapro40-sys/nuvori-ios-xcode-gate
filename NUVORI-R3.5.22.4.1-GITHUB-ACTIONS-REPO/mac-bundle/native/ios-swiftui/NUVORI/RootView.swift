import SwiftUI

struct RootView: View {
    @EnvironmentObject var app: NUVORIAppState
    @StateObject private var speech = LocalFirstSpeechService()
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    TextField("Buscar alimento", text: $app.query).textFieldStyle(.roundedBorder).onSubmit { Task { await app.search(app.query) } }
                    Button(speech.isListening ? "■" : "🎙") {
                        if speech.isListening { speech.stop() }
                        else { Task { await speech.start(foodVocabulary: app.results.flatMap { [$0.name, $0.brand ?? ""] }.filter { !$0.isEmpty }) { text in Task { await app.search(text) } } } }
                    }.accessibilityLabel("Buscar por voz")
                }
                Text(speech.partialText.isEmpty ? speech.status : speech.partialText).font(.footnote).foregroundStyle(.secondary)
                List(app.results) { f in
                    VStack(alignment: .leading) { Text(f.name); if let b=f.brand, !b.isEmpty { Text(b).font(.caption).foregroundStyle(.secondary) } }
                }
            }.padding().navigationTitle("NUVORI")
        }
    }
}
