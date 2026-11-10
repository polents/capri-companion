import SwiftUI
import AVFoundation
import AppKit

struct MainframeWindowRootView: View {
    @ObservedObject var store: AppStore
    @StateObject private var speech = SpeechInputManager()

    var body: some View {
        MainframeView(store: store, speech: speech)
            .frame(width: 496, height: 724)
    }
}

struct MainframeView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var speech: SpeechInputManager
    @State private var memoryDraft = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    identityCard
                    sizeCard
                    personalityCard
                    behaviorCard
                    screenCommentaryCard
                    brainCard
                    voiceCard
                    memoryCard
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                        Text("CHAT + MEMORY STAY ON THIS MAC · NO CLOUD FALLBACK")
                    }
                    .font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(0.5).foregroundStyle(Ink.dim)
                    .padding(.top, 3).padding(.bottom, 8)
                }.padding(14)
            }
            .scrollIndicators(.hidden)
        }
        .background {
            ZStack {
                Ink.background
                RadialGradient(colors: [Ink.accent.opacity(0.10), .clear], center: .topLeading, startRadius: 4, endRadius: 430)
                RadialGradient(colors: [Color(hex: 0x00D9F0).opacity(0.08), .clear], center: .bottomTrailing, startRadius: 2, endRadius: 360)
            }
        }
        .clipShape(CyberCutFrame(cut: 12))
        .overlay(CyberCutFrame(cut: 12).stroke(Ink.accent.opacity(0.55), lineWidth: 1))
        .onDisappear { if speech.isRecording { speech.stop() } }
        .onAppear { store.refreshScreenCommentaryStatus() }
        .onChange(of: store.settings.screenCommentaryEnabled) { enabled in
            if enabled { store.requestScreenCommentaryAccess() }
            else { store.screenCommentaryStatus = "Off" }
        }
        .onChange(of: store.settings.screenCommentaryMinutes) { _ in store.refreshScreenCommentaryStatus() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            SignalMark(color: Ink.accent).frame(width: 23, height: 23)
            VStack(alignment: .leading, spacing: 2) {
                Text("MAINFRAME").font(.system(size: 13, weight: .black, design: .rounded)).tracking(2).foregroundStyle(Ink.accent)
                Text("NIGHT CITY  /  LOCAL CONTROL LINK").font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(0.8).foregroundStyle(Ink.dim)
            }
            Spacer()
            Button {
                closeMainframe()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.left").font(.system(size: 9, weight: .bold))
                    Text("PET").font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(0.8)
                }.foregroundStyle(Ink.accent).padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Ink.panel, in: CyberCutFrame(cut: 8))
            }.buttonStyle(.plain)
            Button(action: closeMainframe) { 
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Ink.muted)
                    .frame(width: 28, height: 28).background(Ink.panel, in: CyberCutFrame(cut: 7))
            }.buttonStyle(.plain).help("Close Mainframe; Capri stays on the desktop")
        }
        .padding(.horizontal, 15).padding(.vertical, 12)
        .background(Ink.background.opacity(0.95))
        .overlay(alignment: .bottom) { Rectangle().fill(Ink.accent.opacity(0.65)).frame(height: 1) }
    }

    private var identityCard: some View {
        MainframeCard(title: "PRESENTATION", subtitle: "THE CHARACTER + STARTUP") {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 10) {
                    CharacterPhoto(wake: store.settings.wake)
                        .frame(width: 52, height: 65).background(Ink.background, in: RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Ink.line, lineWidth: 1))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CAPRI").font(.system(size: 16, weight: .black, design: .rounded)).tracking(1.5).foregroundStyle(store.settings.palette.primary)
                        Text("A desktop companion with a warm deadpan voice. Curious, kind, and not clingy.")
                            .font(.system(size: 10)).foregroundStyle(Ink.muted).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }.padding(.bottom, 2)
                SmallLabel(text: "STARTUP INTRO")
                HStack(spacing: 7) {
                    ForEach(WakePreset.allCases) { preset in
                        Button { store.settings.wake = preset } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Image(systemName: wakeIcon(preset)).font(.system(size: 20, weight: .light))
                                    .foregroundStyle(store.settings.wake == preset ? store.settings.palette.primary : Ink.dim)
                                    .frame(maxWidth: .infinity, minHeight: 38, maxHeight: 38, alignment: .center)
                                Text(preset.displayName.uppercased()).font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(0.3).foregroundStyle(Ink.text)
                                Text(preset.detail).font(.system(size: 8)).foregroundStyle(Ink.dim).lineLimit(2).multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, minHeight: 66, alignment: .topLeading).padding(8)
                            .background(store.settings.wake == preset ? store.settings.palette.primary.opacity(0.07) : Ink.background, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(store.settings.wake == preset ? store.settings.palette.primary.opacity(0.42) : Ink.line, lineWidth: 1))
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var personalityCard: some View {
        MainframeCard(title: "PERSONALITY", subtitle: "ADJUST HER SOCIAL TEMPERATURE") {
            HStack(spacing: 9) {
                SettingsMenu(title: "SPEAKING STYLE", value: $store.settings.speakingStyle,
                             options: ["Warm deadpan", "Soft and thoughtful", "Bright and playful", "Short and direct"])
                SettingsMenu(title: "MOOD", value: $store.settings.mood,
                             options: ["Curious", "Calm", "Playful", "Dreamy", "Focused"])
            }
            SettingSlider(title: "HUMOR", value: $store.settings.humor, left: "DRY", right: "GOOFY", accent: store.settings.palette.primary)
            SettingSlider(title: "FRIENDLINESS", value: $store.settings.friendliness, left: "RESERVED", right: "WARM", accent: store.settings.palette.primary)
            SettingSlider(title: "SASS", value: $store.settings.sass, left: "GENTLE", right: "CHEEKY", accent: store.settings.palette.primary)
        }
    }

    private var sizeCard: some View {
        MainframeCard(title: "PET SCALE", subtitle: "DESKTOP + CHAT SIZE") {
            HStack(spacing: 10) {
                Image(systemName: "minus.magnifyingglass").foregroundStyle(Ink.dim)
                Slider(value: Binding(get: { store.petScale }, set: { store.setPetScale($0) }), in: 0.60...1.45)
                    .tint(Ink.accent).controlSize(.small)
                Image(systemName: "plus.magnifyingglass").foregroundStyle(Ink.dim)
                Text("\(Int(store.petScale * 100))%")
                    .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(Ink.accent)
                    .frame(width: 38, alignment: .trailing)
            }
            HStack(spacing: 7) {
                ForEach([0.75, 1.0, 1.25], id: \.self) { scale in
                    Button { store.setPetScale(scale) } label: {
                        Text("\(Int(scale * 100))%")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(abs(store.petScale - scale) < 0.02 ? Ink.accent : Ink.muted)
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                            .background(Ink.background, in: CyberCutFrame(cut: 5))
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private var behaviorCard: some View {
        MainframeCard(title: "BEHAVIOR", subtitle: "PRESENCE WITHOUT PRESSURE") {
            SettingSlider(title: "PROACTIVITY", value: $store.settings.proactivity, left: "QUIET", right: "PRESENT", accent: store.settings.palette.primary)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CHECK-IN WINDOW").font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(0.6).foregroundStyle(Ink.muted)
                    Text("Only after a stretch without chatting").font(.system(size: 9)).foregroundStyle(Ink.dim)
                }
                Spacer()
                Picker("Check in", selection: $store.settings.checkInMinutes) {
                    Text("Off").tag(0)
                    Text("15 min").tag(15)
                    Text("30 min").tag(30)
                    Text("60 min").tag(60)
                }.labelsHidden().pickerStyle(.menu).frame(width: 94)
            }.padding(.top, 3)
            Divider().overlay(Ink.line)
            Toggle(isOn: $store.settings.quietMode) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("QUIET MODE").font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(0.6).foregroundStyle(Ink.text)
                    Text("No spontaneous check-ins").font(.system(size: 9)).foregroundStyle(Ink.dim)
                }
            }.toggleStyle(.switch).tint(store.settings.palette.primary)
        }
    }

    private var screenCommentaryCard: some View {
        MainframeCard(title: "SCREEN COMMENTARY", subtitle: "OPT-IN / LOCAL OCR") {
            Toggle(isOn: $store.settings.screenCommentaryEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("COMMENT ON VISIBLE TEXT").font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(0.5).foregroundStyle(Ink.text)
                    Text("Read text on your screen occasionally and offer a short remark.").font(.system(size: 9)).foregroundStyle(Ink.dim)
                }
            }.toggleStyle(.switch).tint(Ink.accent)

            HStack {
                Text("CHECK INTERVAL").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(Ink.muted)
                Spacer()
                Picker("Screen check interval", selection: $store.settings.screenCommentaryMinutes) {
                    Text("5 min").tag(5)
                    Text("15 min").tag(15)
                    Text("30 min").tag(30)
                }.labelsHidden().pickerStyle(.menu).frame(width: 86)
                    .disabled(!store.settings.screenCommentaryEnabled)
            }
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: store.settings.screenCommentaryEnabled ? "eye" : "eye.slash")
                    .foregroundStyle(store.settings.screenCommentaryEnabled ? Ink.electric : Ink.dim)
                Text(store.settings.screenCommentaryEnabled
                     ? "OCR runs on this Mac. Only extracted text is sent to your local Ollama model; screenshots and OCR text are not saved. Quiet Mode pauses it."
                     : "Off by default. Capri never reads the screen until you enable this and grant macOS Screen Recording access.")
                    .font(.system(size: 8)).foregroundStyle(Ink.dim).fixedSize(horizontal: false, vertical: true)
            }
            Text(store.screenCommentaryStatus)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(store.settings.screenCommentaryEnabled ? Ink.electric : Ink.dim)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button { store.requestScreenCommentaryAccess() } label: {
                    Label("REQUEST / CHECK ACCESS", systemImage: "checkmark.shield")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(Ink.background).padding(.horizontal, 9).padding(.vertical, 7)
                        .background(Ink.accent, in: CyberCutFrame(cut: 6))
                }.buttonStyle(.plain).disabled(!store.settings.screenCommentaryEnabled)
                Button("OPEN PRIVACY SETTINGS") { openScreenRecordingSettings() }
                    .font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(Ink.muted)
                    .buttonStyle(.plain)
            }
        }
    }

    private var brainCard: some View {
        MainframeCard(title: "BRAIN", subtitle: "OLLAMA / LOCAL GENERATION") {
            HStack(spacing: 7) {
                Circle().fill(brainColor).frame(width: 7, height: 7)
                Text(store.ollamaState.shortTitle).font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(0.6).foregroundStyle(brainColor)
                Spacer()
                Button { Task { await store.refreshConnection() } } label: {
                    Label("RETRY", systemImage: "arrow.clockwise").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(Ink.muted)
                }.buttonStyle(.plain)
            }
            Text(store.statusMessage.isEmpty ? "Checking 127.0.0.1:11434…" : store.statusMessage)
                .font(.system(size: 9)).foregroundStyle(Ink.muted).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 7) {
                Image(systemName: "cpu").foregroundStyle(store.settings.palette.primary).font(.system(size: 11))
                TextField("Ollama model name", text: $store.settings.model)
                    .textFieldStyle(.plain).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(Ink.text)
                    .onSubmit { Task { await store.refreshConnection() } }
            }
            .padding(9).background(Ink.background, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Ink.line, lineWidth: 1))
            HStack(spacing: 8) {
                Button {
                    Task { await store.pullSelectedModel() }
                } label: {
                    HStack(spacing: 6) {
                        if store.isPulling { ProgressView().controlSize(.mini).tint(Ink.background) }
                        else { Image(systemName: "arrow.down.to.line.compact") }
                        Text(store.isPulling ? "PULLING MODEL" : "PULL SELECTED MODEL")
                    }
                    .font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(0.45)
                    .foregroundStyle(Ink.background).padding(.horizontal, 10).padding(.vertical, 8)
                    .background(store.settings.palette.primary, in: RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain).disabled(store.isPulling)
                Text("Uses Ollama's local model library")
                    .font(.system(size: 8)).foregroundStyle(Ink.dim)
            }
            if !store.installedModels.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    SmallLabel(text: "INSTALLED MODELS · TAP TO SELECT")
                    ScrollView(.horizontal) {
                        HStack(spacing: 6) {
                            ForEach(store.installedModels, id: \.self) { model in
                                Button { store.settings.model = model; Task { await store.refreshConnection() } } label: {
                                    Text(model).font(.system(size: 8, weight: .medium, design: .monospaced))
                                        .foregroundStyle(model == store.settings.model ? store.settings.palette.primary : Ink.muted)
                                        .padding(.horizontal, 8).padding(.vertical, 6)
                                        .background(Ink.background, in: Capsule())
                                        .overlay(Capsule().stroke(model == store.settings.model ? store.settings.palette.primary.opacity(0.4) : Ink.line, lineWidth: 1))
                                }.buttonStyle(.plain)
                            }
                        }
                    }.scrollIndicators(.hidden)
                }
            } else {
                Text("If Ollama is offline, start it first. Default model: gemma4:e4b. No remote model is used.")
                    .font(.system(size: 8)).foregroundStyle(Ink.dim).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var voiceCard: some View {
        MainframeCard(title: "VOICE", subtitle: "OPTIONAL / MACOS SPEECH SERVICES") {
            Toggle(isOn: $store.settings.voiceInput) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SPEECH INPUT").font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(0.6).foregroundStyle(Ink.text)
                    Text("Dictate into chat when you tap the mic.").font(.system(size: 9)).foregroundStyle(Ink.dim)
                }
            }.toggleStyle(.switch).tint(store.settings.palette.primary)
            Toggle(isOn: $store.settings.spokenReplies) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SPOKEN REPLIES").font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(0.6).foregroundStyle(Ink.text)
                    Text("Use the selected built-in macOS voice.").font(.system(size: 9)).foregroundStyle(Ink.dim)
                }
            }.toggleStyle(.switch).tint(store.settings.palette.primary)
            if store.settings.spokenReplies {
                Picker("Voice", selection: $store.settings.voiceIdentifier) {
                    Text("System default").tag("")
                    ForEach(AVSpeechSynthesisVoice.speechVoices(), id: \.identifier) { voice in
                        Text("\(voice.name) · \(voice.language)").tag(voice.identifier)
                    }
                }.font(.system(size: 9)).pickerStyle(.menu)
            }
            if store.settings.voiceInput {
                HStack(spacing: 9) {
                    Button { speech.toggle(); store.recordActivity() } label: {
                        Label(speech.isRecording ? "STOP MICROPHONE" : "TEST MICROPHONE", systemImage: speech.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(speech.isRecording ? Color(hex: 0xFF8293) : store.settings.palette.primary)
                            .padding(.horizontal, 9).padding(.vertical, 8).background(Ink.background, in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain)
                    Text(speech.isRecording ? "Listening now" : "Mic is off")
                        .font(.system(size: 9, weight: .medium)).foregroundStyle(speech.isRecording ? store.settings.palette.primary : Ink.dim)
                }
                if !speech.transcript.isEmpty {
                    Text("Heard: \(speech.transcript)").font(.system(size: 9)).foregroundStyle(Ink.muted).fixedSize(horizontal: false, vertical: true)
                }
                if !speech.errorMessage.isEmpty {
                    Text(speech.errorMessage).font(.system(size: 9)).foregroundStyle(Color(hex: 0xFF9B9F)).fixedSize(horizontal: false, vertical: true)
                }
                Text("The mic is only active while you start it. Speech recognition is provided by macOS.")
                    .font(.system(size: 8)).foregroundStyle(Ink.dim).fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Both voice features are off until you enable them here.").font(.system(size: 9)).foregroundStyle(Ink.dim)
            }
        }
    }

    private var memoryCard: some View {
        MainframeCard(title: "MEMORY", subtitle: "USER-MANAGED / STORED ON THIS MAC") {
            Text("Add details Capri can use in future chats. Keep or remove anything whenever you like.")
                .font(.system(size: 9)).foregroundStyle(Ink.muted).fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .bottom, spacing: 7) {
                TextField("A preference, project, or detail…", text: $memoryDraft, axis: .vertical)
                    .lineLimit(1...3).textFieldStyle(.plain).font(.system(size: 10)).foregroundStyle(Ink.text)
                    .padding(9).background(Ink.background, in: RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Ink.line, lineWidth: 1))
                    .onSubmit(addMemory)
                Button(action: addMemory) {
                    Image(systemName: "plus").font(.system(size: 11, weight: .bold)).foregroundStyle(Ink.background)
                        .frame(width: 32, height: 32).background(store.settings.palette.primary, in: RoundedRectangle(cornerRadius: 9))
                }.buttonStyle(.plain).disabled(memoryDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if store.memories.isEmpty {
                HStack(spacing: 7) {
                    Image(systemName: "square.stack.3d.up").foregroundStyle(Ink.dim)
                    Text("No saved memories yet.").foregroundStyle(Ink.dim)
                }.font(.system(size: 9)).padding(.vertical, 3)
            } else {
                VStack(spacing: 7) {
                    ForEach(store.memories) { item in
                        MemoryRow(item: item, accent: store.settings.palette.primary,
                                  onChange: { store.updateMemory(item.id, text: $0) },
                                  onDelete: { store.deleteMemory(item.id) })
                    }
                }
            }
        }
    }

    private var brainColor: Color {
        switch store.ollamaState {
        case .connected: return store.settings.palette.primary
        case .checking: return Color(hex: 0xFFC76B)
        case .missingModel, .unavailable: return Color(hex: 0xFF9B9F)
        }
    }

    private func wakeIcon(_ preset: WakePreset) -> String {
        switch preset {
        case .softBoot: return "sparkle"
        case .prismWake: return "circle.lefthalf.filled"
        case .orbitSync: return "circle.dashed.inset.filled"
        }
    }

    private func addMemory() {
        store.addMemory(memoryDraft)
        memoryDraft = ""
    }

    private func closeMainframe() {
        if speech.isRecording { speech.stop() }
        CompanionController.shared.closeMainframe()
    }

    private func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }
}

private struct MainframeCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(size: 10, weight: .black, design: .monospaced)).tracking(1.15).foregroundStyle(Ink.accent)
                Spacer()
                Text(subtitle).font(.system(size: 7, weight: .medium, design: .monospaced)).tracking(0.65).foregroundStyle(Ink.dim)
            }
            Rectangle().fill(LinearGradient(colors: [Ink.accent.opacity(0.62), Ink.electric.opacity(0.14), Ink.line], startPoint: .leading, endPoint: .trailing)).frame(height: 1)
            content
        }
        .padding(11).background(Ink.panel.opacity(0.96), in: CyberCutFrame(cut: 11))
        .overlay(CyberCutFrame(cut: 11).stroke(Ink.accent.opacity(0.20), lineWidth: 1))
        .overlay(alignment: .leading) { Rectangle().fill(Ink.accent.opacity(0.72)).frame(width: 2).padding(.vertical, 11) }
    }
}

private struct CyberCutFrame: Shape {
    var cut: CGFloat
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
            path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cut))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
            path.closeSubpath()
        }
    }
}

private struct SmallLabel: View {
    let text: String
    var body: some View { Text(text).font(.system(size: 7, weight: .bold, design: .monospaced)).tracking(0.8).foregroundStyle(Ink.dim) }
}

private struct SettingsMenu: View {
    let title: String
    @Binding var value: String
    let options: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SmallLabel(text: title)
            Picker(title, selection: $value) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }.labelsHidden().pickerStyle(.menu).font(.system(size: 9)).frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8).padding(.vertical, 2).background(Ink.background, in: RoundedRectangle(cornerRadius: 8))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingSlider: View {
    let title: String
    @Binding var value: Double
    let left: String
    let right: String
    let accent: Color
    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Text(title).font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(0.6).foregroundStyle(Ink.muted)
                Spacer()
                Text(valueLabel).font(.system(size: 8, weight: .medium, design: .monospaced)).foregroundStyle(accent.opacity(0.9))
            }
            Slider(value: $value, in: 0...1).tint(accent).controlSize(.small)
            HStack {
                Text(left).frame(maxWidth: .infinity, alignment: .leading)
                Text(right).frame(maxWidth: .infinity, alignment: .trailing)
            }.font(.system(size: 7, weight: .medium, design: .monospaced)).foregroundStyle(Ink.dim)
        }
    }
    private var valueLabel: String {
        switch value {
        case ..<0.25: return "LOW"
        case ..<0.65: return "MID"
        default: return "HIGH"
        }
    }
}

private struct MemoryRow: View {
    let item: MemoryItem
    let accent: Color
    var onChange: (String) -> Void
    var onDelete: () -> Void
    @State private var text = ""
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(accent.opacity(0.8)).frame(width: 2).padding(.vertical, 2)
            TextEditor(text: $text)
                .font(.system(size: 10)).foregroundStyle(Ink.text).scrollContentBackground(.hidden)
                .frame(minHeight: 34, maxHeight: 84).fixedSize(horizontal: false, vertical: true)
                .onChange(of: text) { onChange($0) }
            Button(action: onDelete) {
                Image(systemName: "trash").font(.system(size: 10)).foregroundStyle(Color(hex: 0xD6818D))
                    .frame(width: 25, height: 25).background(Ink.panelRaised, in: RoundedRectangle(cornerRadius: 7))
            }.buttonStyle(.plain).help("Delete memory")
        }
        .padding(7).background(Ink.background, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Ink.line, lineWidth: 1))
        .onAppear { text = item.text }
    }
}
