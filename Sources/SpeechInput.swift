import Foundation
import Combine
import AVFoundation
import Speech

@MainActor
final class SpeechInputManager: ObservableObject {
    @Published var isRecording = false
    @Published var transcript = ""
    @Published var errorMessage = ""

    private let engine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func toggle() {
        if isRecording { stop(); return }
        transcript = ""
        errorMessage = ""
        SFSpeechRecognizer.requestAuthorization { [weak self] speechStatus in
            DispatchQueue.main.async {
                guard let self else { return }
                guard speechStatus == .authorized else {
                    self.errorMessage = "Allow speech recognition in macOS Privacy & Security to use dictation."
                    return
                }
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    DispatchQueue.main.async {
                        guard granted else {
                            self.errorMessage = "Microphone access is off. Allow it in macOS Privacy & Security."
                            return
                        }
                        self.beginRecording()
                    }
                }
            }
        }
    }

    private func beginRecording() {
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition is unavailable right now."
            return
        }
        guard recognizer.supportsOnDeviceRecognition else {
            errorMessage = "On-device speech recognition isn't available for this macOS language setup, so the microphone remains off."
            return
        }
        do {
            let audioRequest = SFSpeechAudioBufferRecognitionRequest()
            audioRequest.shouldReportPartialResults = true
            audioRequest.requiresOnDeviceRecognition = true
            request = audioRequest
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak audioRequest] buffer, _ in
                audioRequest?.append(buffer)
            }
            engine.prepare()
            try engine.start()
            isRecording = true
            task = recognizer.recognitionTask(with: audioRequest) { [weak self] result, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if let result { self.transcript = result.bestTranscription.formattedString }
                    if error != nil || result?.isFinal == true { self.stop() }
                }
            }
        } catch {
            errorMessage = "Couldn't start the microphone: \(error.localizedDescription)"
            stop()
        }
    }

    func stop() {
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isRecording = false
    }
}
