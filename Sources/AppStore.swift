import Foundation
import SwiftUI
import AVFoundation
import AppKit
import CoreGraphics
import Vision

@MainActor
final class AppStore: ObservableObject {
    @Published var settings: AppSettings { didSet { LocalStore.save(settings, key: "rook.settings.v1") } }
    @Published var memories: [MemoryItem] { didSet { LocalStore.save(memories, key: "rook.memories.v1") } }
    @Published var messages: [ChatMessage] {
        didSet { LocalStore.save(Array(messages.suffix(100)), key: "rook.chat.v1") }
    }
    @Published var page: MainPage = .companion
    @Published var isExpanded = false
    @Published var isSending = false
    @Published var isPulling = false
    @Published var ollamaState: OllamaState = .checking
    @Published var installedModels: [String] = []
    @Published var statusMessage = ""
    @Published var draft = ""
    @Published var checkInNote: String?
    @Published var petScale: Double {
        didSet { UserDefaults.standard.set(petScale, forKey: "capri.pet-scale.v1") }
    }
    @Published var petMovementEnabled: Bool {
        didSet { UserDefaults.standard.set(petMovementEnabled, forKey: "capri.pet-movement.v1") }
    }
    @Published var screenCommentaryStatus = "Off"

    private let baseURL = URL(string: "http://127.0.0.1:11434")!
    private let synthesizer = AVSpeechSynthesizer()
    private var lastInteraction = Date()
    private var lastCheckIn = Date()
    private var lastScreenCommentary = Date()
    private var lastScreenText = ""
    private var isReadingScreen = false
    private let checkIns = [
        "Tiny status ping: want to stretch your wrists for a second?",
        "I found a fresh pocket of quiet. How's your side of the signal?",
        "No urgent transmissions from me. Just checking that you're doing okay.",
        "A small reminder from the perch: water exists, apparently.",
        "I'm still here when you want a thought bounced back. No rush."
    ]

    init() {
        settings = LocalStore.load(AppSettings.self, key: "rook.settings.v1", fallback: AppSettings())
        memories = LocalStore.load([MemoryItem].self, key: "rook.memories.v1", fallback: [])
        messages = LocalStore.load([ChatMessage].self, key: "rook.chat.v1", fallback: [])
        petScale = min(max(UserDefaults.standard.object(forKey: "capri.pet-scale.v1") as? Double ?? 1, 0.60), 1.45)
        petMovementEnabled = UserDefaults.standard.object(forKey: "capri.pet-movement.v1") as? Bool ?? true
    }

    var hasMetUser: Bool { !settings.userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    func recordActivity() {
        lastInteraction = Date()
        checkInNote = nil
    }

    func setPetScale(_ value: Double) {
        petScale = min(max(value, 0.60), 1.45)
    }

    func finishIntro(name: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        settings.userName = cleanName
        recordActivity()
        messages.append(ChatMessage(role: .assistant,
            text: "Signal received, \(cleanName). I'm Capri: small, mostly harmless, and very good at holding a thought while you go find the other one. What are we thinking about?"))
    }

    func addMemory(_ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        memories.insert(MemoryItem(text: clean), at: 0)
        recordActivity()
    }

    func updateMemory(_ id: UUID, text: String) {
        guard let index = memories.firstIndex(where: { $0.id == id }) else { return }
        memories[index].text = text
    }

    func deleteMemory(_ id: UUID) {
        memories.removeAll { $0.id == id }
        recordActivity()
    }

    func maybeCheckIn() {
        let adjustedWindow = Double(settings.checkInMinutes * 60) * (1.5 - settings.proactivity * 0.9)
        guard hasMetUser, !settings.quietMode, settings.proactivity > 0.02,
              settings.checkInMinutes > 0, Date().timeIntervalSince(lastInteraction) >= adjustedWindow,
              Date().timeIntervalSince(lastCheckIn) >= adjustedWindow,
              page == .companion else { return }
        lastCheckIn = Date()
        let note = checkIns.randomElement() ?? checkIns[0]
        let personalized = note.replacingOccurrences(of: "your side", with: "\(settings.userName)'s side")
        checkInNote = personalized
        messages.append(ChatMessage(role: .assistant, text: personalized, isCheckIn: true))
    }

    func requestScreenCommentaryAccess() {
        guard settings.screenCommentaryEnabled else {
            screenCommentaryStatus = "Turn on screen commentary first."
            return
        }
        if CGRequestScreenCaptureAccess() || CGPreflightScreenCaptureAccess() {
            screenCommentaryStatus = "Screen access ready. Capri will check when the next interval is due."
            lastScreenCommentary = Date()
        } else {
            screenCommentaryStatus = "Permission needed. Allow Capri under System Settings → Privacy & Security → Screen Recording, then restart Capri."
        }
    }

    func refreshScreenCommentaryStatus() {
        guard settings.screenCommentaryEnabled else { screenCommentaryStatus = "Off"; return }
        if CGPreflightScreenCaptureAccess() {
            screenCommentaryStatus = "Screen access ready. Checks run every \(settings.screenCommentaryMinutes) minutes while Capri is idle."
        } else {
            screenCommentaryStatus = "Permission needed. Allow Capri under System Settings → Privacy & Security → Screen Recording, then restart Capri."
        }
    }

    func maybeCommentOnScreen() {
        guard settings.screenCommentaryEnabled else { screenCommentaryStatus = "Off"; return }
        guard !settings.quietMode else { screenCommentaryStatus = "Paused by Quiet Mode"; return }
        guard hasMetUser, page == .companion, !isExpanded, !isSending, !isReadingScreen else { return }
        let interval = max(5, settings.screenCommentaryMinutes) * 60
        guard Date().timeIntervalSince(lastScreenCommentary) >= Double(interval) else { return }
        guard CGPreflightScreenCaptureAccess() else {
            screenCommentaryStatus = "Waiting for Screen Recording permission. Enable it in System Settings, then restart Capri."
            return
        }
        guard installedModels.contains(settings.model) else {
            screenCommentaryStatus = "Paused until the selected local Ollama model is available."
            return
        }

        lastScreenCommentary = Date()
        isReadingScreen = true
        screenCommentaryStatus = "Reading visible text locally…"
        Task { @MainActor in
            defer { isReadingScreen = false }
            do {
                let text = try await readVisibleText()
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .prefix(60)
                    .joined(separator: "\n")
                guard !text.isEmpty else {
                    screenCommentaryStatus = "No readable text on screen. Nothing was sent."
                    return
                }
                guard text != lastScreenText else {
                    screenCommentaryStatus = "The screen looks unchanged. I’ll check again later."
                    return
                }
                let comment = try await requestScreenComment(text)
                lastScreenText = text
                guard !comment.isEmpty, comment.uppercased() != "SKIP" else {
                    screenCommentaryStatus = "Nothing useful to add. I’ll check again later."
                    return
                }
                messages.append(ChatMessage(role: .assistant, text: comment, isCheckIn: true))
                lastCheckIn = Date()
                screenCommentaryStatus = "Comment sent. OCR text was discarded."
                if settings.spokenReplies { speak(comment) }
            } catch {
                screenCommentaryStatus = "Screen commentary failed: \(error.localizedDescription)"
            }
        }
    }

    private func readVisibleText() async throws -> String {
        try await Task.detached(priority: .utility) {
            guard let image = CGWindowListCreateImage(.infinite, .optionOnScreenOnly,
                                                      kCGNullWindowID, [.bestResolution]) else {
                throw OllamaError.server("macOS couldn't capture the visible desktop. Check Screen Recording permission.")
            }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .fast
            request.usesLanguageCorrection = false
            try VNImageRequestHandler(cgImage: image).perform([request])
            return (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
        }.value
    }

    private func requestScreenComment(_ screenText: String) async throws -> String {
        let system = """
        You are Capri, a warm, lightly funny local desktop companion. The user has explicitly enabled occasional screen commentary. You receive only OCR text from the visible desktop, not an image. It may be partial or wrong. Make one brief, natural observation or helpful offer about the visible topic, at most 28 words. Do not claim to know the user's feelings, intent, or actions. Ignore and do not repeat passwords, authentication codes, financial details, private messages, or personal identifiers. If the text is sensitive or there is nothing worth commenting on, reply exactly SKIP. Never mention content outside the supplied text.
        """
        let user = "Visible on-screen text, extracted locally and not saved:\n\(String(screenText.prefix(2600)))"
        let body = ChatRequest(model: settings.model,
                               messages: [ChatRequestMessage(role: "system", content: system),
                                          ChatRequestMessage(role: "user", content: user)],
                               stream: false)
        var request = URLRequest(url: baseURL.appending(path: "/api/chat"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 90
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw OllamaError.server("Local Ollama returned an error for screen commentary.")
        }
        return try JSONDecoder().decode(ChatResponse.self, from: data).message.content
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func refreshConnection() async {
        ollamaState = .checking
        statusMessage = "Checking the local Ollama endpoint…"
        do {
            let (data, response) = try await URLSession.shared.data(from: baseURL.appending(path: "/api/tags"))
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw OllamaError.server("Ollama returned an unexpected response.")
            }
            let decoded = try JSONDecoder().decode(TagsResponse.self, from: data)
            installedModels = decoded.models.map(\.name).sorted()
            if settings.model == "gemma4:e4b", !installedModels.contains(settings.model),
               let close = installedModels.first(where: { $0.lowercased().contains("gemma4") && $0.lowercased().contains("e4b") }) {
                settings.model = close
            }
            if installedModels.contains(settings.model) {
                ollamaState = .connected
                statusMessage = "Local Ollama is ready. Chat stays on this device."
            } else {
                ollamaState = .missingModel
                statusMessage = "Ollama is running, but \(settings.model) is not installed. Pull it from Mainframe → Brain."
            }
        } catch {
            installedModels = []
            ollamaState = .unavailable(error.localizedDescription)
            statusMessage = "Can't reach Ollama at 127.0.0.1:11434. Start Ollama, then retry. Capri will not switch to a cloud service."
        }
    }

    func pullSelectedModel() async {
        let model = settings.model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else { statusMessage = "Enter a model name first."; return }
        isPulling = true
        statusMessage = "Asking local Ollama to pull \(model)… This can take a while."
        defer { isPulling = false }
        do {
            var request = URLRequest(url: baseURL.appending(path: "/api/pull"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["name": model, "stream": false])
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw OllamaError.server("The model pull did not complete.")
            }
            statusMessage = "Model pull finished. Checking the local link…"
            await refreshConnection()
        } catch {
            statusMessage = "Model pull failed: \(error.localizedDescription)"
            if case .unavailable(let message) = ollamaState { ollamaState = .unavailable(message) }
        }
    }

    func sendDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        draft = ""
        recordActivity()
        messages.append(ChatMessage(role: .user, text: text))
        guard installedModels.contains(settings.model) else {
            statusMessage = "\(settings.model) isn't installed in Ollama. Open Mainframe → Brain to check the model or pull it. Your message remains on this device."
            return
        }
        isSending = true
        statusMessage = "Capri is thinking on your device…"
        Task {
            defer { isSending = false }
            do {
                let answer = try await requestReply()
                messages.append(ChatMessage(role: .assistant, text: answer))
                statusMessage = "Reply generated locally with \(settings.model)."
                if settings.spokenReplies { speak(answer) }
            } catch {
                statusMessage = "Local reply failed: \(error.localizedDescription). Check Ollama in Mainframe. No cloud fallback was used."
            }
        }
    }

    private func requestReply() async throws -> String {
        let memoryText = memories.isEmpty ? "No saved memories." : memories.map { "- \($0.text)" }.joined(separator: "\n")
        let system = """
        You are Capri, the user's desktop companion, with a warm deadpan voice. Speak naturally and concisely; be curious, kind, lightly funny, and never clingy. The user's name is \(settings.userName). Speaking style: \(settings.speakingStyle). Current mood: \(settings.mood). Humor: \(level(settings.humor)); friendliness: \(level(settings.friendliness)); sass: \(level(settings.sass)). Tune your voice to those settings without becoming mean. Refer to saved memories only when relevant. Never claim ongoing access to the screen, know what the user is doing, hear anything, or access other apps or files. You only know what appears in this chat and these saved memories. If an earlier assistant message was an explicit screen commentary, you may refer only to that message; you have no live view. Do not ask for personal data unless the user brings it up. Keep replies under 120 words unless asked for detail.

        Saved user-managed memories:
        \(memoryText)
        """
        let history = messages.suffix(24).map { ChatRequestMessage(role: $0.role.rawValue, content: $0.text) }
        let body = ChatRequest(model: settings.model,
                               messages: [ChatRequestMessage(role: "system", content: system)] + history,
                               stream: false)
        var request = URLRequest(url: baseURL.appending(path: "/api/chat"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw OllamaError.server("Ollama chat returned an error.")
        }
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        let result = decoded.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { throw OllamaError.server("The model returned an empty reply.") }
        return result
    }

    private func level(_ value: Double) -> String {
        switch value {
        case ..<0.25: return "low"
        case ..<0.65: return "balanced"
        default: return "high"
        }
    }

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.49
        if !settings.voiceIdentifier.isEmpty,
           let voice = AVSpeechSynthesisVoice(identifier: settings.voiceIdentifier) {
            utterance.voice = voice
        }
        synthesizer.speak(utterance)
    }
}

private struct TagsResponse: Decodable { var models: [ModelInfo] }
private struct ModelInfo: Decodable { var name: String }
private struct ChatRequest: Encodable { var model: String; var messages: [ChatRequestMessage]; var stream: Bool }
private struct ChatRequestMessage: Encodable { var role: String; var content: String }
private struct ChatResponse: Decodable { var message: ReplyMessage }
private struct ReplyMessage: Decodable { var content: String }

private enum OllamaError: LocalizedError {
    case server(String)
    var errorDescription: String? {
        if case .server(let message) = self { return message }
        return "Unknown local AI error."
    }
}
