import AVFoundation
import Speech

@MainActor
final class LocalFirstSpeechService: ObservableObject {
    @Published var isListening = false
    @Published var partialText = ""
    @Published var status = ""

    private let engine = AVAudioEngine()
    private var task: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var tapInstalled = false
    private var sessionID: UInt64 = 0

    func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        let mic = await AVAudioApplication.requestRecordPermission()
        return speech && mic
    }

    func start(
        locale: Locale = .current,
        foodVocabulary: [String] = [],
        onFinal: @escaping (String) -> Void
    ) async {
        guard await requestPermissions() else {
            status = "Permiso de micrófono o voz denegado"
            return
        }
        cancel()
        sessionID &+= 1
        let voiceSessionID = sessionID
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            status = "Reconocimiento no disponible"
            return
        }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.taskHint = .search
        req.contextualStrings = Array(foodVocabulary.prefix(100))
        if recognizer.supportsOnDeviceRecognition {
            req.requiresOnDeviceRecognition = true
            status = "En dispositivo · sin API NUVORI"
        } else {
            req.requiresOnDeviceRecognition = false
            status = "Servicio de voz del sistema"
        }
        request = req

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            status = error.localizedDescription
            return
        }

        let node = engine.inputNode
        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            req.append(buffer)
        }
        tapInstalled = true
        engine.prepare()
        do {
            try engine.start()
            isListening = true
        } catch {
            status = error.localizedDescription
            stop()
            return
        }

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            Task { @MainActor in
                guard let self, voiceSessionID == self.sessionID else { return }
                if let text = result?.bestTranscription.formattedString {
                    self.partialText = text
                }
                if result?.isFinal == true {
                    let text = result?.bestTranscription.formattedString ?? ""
                    self.sessionID &+= 1
                    self.cleanup(cancelTask: false)
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { onFinal(text) }
                } else if let error {
                    self.status = error.localizedDescription
                    self.sessionID &+= 1
                    self.cleanup(cancelTask: true)
                }
            }
        }
    }

    // Finish the utterance and allow the recognizer to return its final result.
    func stop() {
        if engine.isRunning { engine.stop() }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        request?.endAudio()
        isListening = false
    }

    // Cancel means discard: invalidate this session before cancelling the platform task.
    func cancel() {
        sessionID &+= 1
        cleanup(cancelTask: true)
    }

    private func cleanup(cancelTask: Bool) {
        if engine.isRunning { engine.stop() }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        request?.endAudio()
        if cancelTask { task?.cancel() }
        task = nil
        request = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
