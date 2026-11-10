import SwiftUI
import AppKit
import Combine

enum Ink {
    static let background = Color(hex: 0x07090B)
    static let panel = Color(hex: 0x0E1215)
    static let panelRaised = Color(hex: 0x171C20)
    static let line = Color(hex: 0x303A3D)
    static let text = Color(hex: 0xF3F2E8)
    static let muted = Color(hex: 0xA5B0B1)
    static let dim = Color(hex: 0x748083)
    static let accent = Color(hex: 0xF3E600)
    static let electric = Color(hex: 0x00DAEF)
}

struct CompanionRootView: View {
    @ObservedObject var store: AppStore
    @StateObject private var speech = SpeechInputManager()
    @State private var panel: NSWindow?

    private var panelSize: CGSize {
        let scale = CGFloat(store.petScale)
        if store.isExpanded {
            return CGSize(width: 380, height: CGFloat(store.hasMetUser ? 620 : 520) + max(0, (scale - 1) * 342))
        }
        return CGSize(width: 184 * scale, height: 316 * scale)
    }

    var body: some View {
        Group {
            if store.isExpanded { expandedCompanion }
            else { compactCompanion }
        }
        .frame(width: panelSize.width, height: panelSize.height)
        .background(Color.clear)
        .background(WindowAccessor { panel = $0 })
        .onChange(of: store.isExpanded) { _ in resizePanel() }
        .onChange(of: store.settings.userName) { _ in resizePanel() }
        .onChange(of: store.petScale) { _ in resizePanel() }
        .onChange(of: store.petMovementEnabled) { enabled in panel?.isMovableByWindowBackground = enabled }
        .onChange(of: speech.transcript) { text in
            if !text.isEmpty { store.draft = text }
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            store.maybeCheckIn()
            store.maybeCommentOnScreen()
        }
        .onAppear { resizePanel(animated: false) }
        .environment(\.colorScheme, .dark)
    }

    private var expandedCompanion: some View {
        ChatPetView(store: store, speech: speech, menu: petContextMenu, openMainframe: openMainframe)
    }

    private var compactCompanion: some View {
        CharacterPhoto(wake: store.settings.wake).frame(width: 178 * CGFloat(store.petScale), height: 306 * CGFloat(store.petScale))
            .contentShape(Rectangle())
            .onTapGesture(perform: openChat)
            .contextMenu { petContextMenu }
    }

    @ViewBuilder private var petContextMenu: some View {
        Button { openChat() } label: { Label("Talk to her", systemImage: "bubble.left") }
        Button { CompanionController.shared.setPetMovementEnabled(false) } label: { Label("Sit here", systemImage: "figure.stand") }
        Menu("Move") {
            Button("Enable dragging") { CompanionController.shared.setPetMovementEnabled(true) }
            Button("Return to lower-right corner") { CompanionController.shared.resetPetPosition() }
        }
        Menu("Size") {
            ForEach([0.60, 0.75, 1.0, 1.25, 1.45], id: \.self) { scale in
                Button {
                    store.setPetScale(scale)
                } label: {
                    if abs(store.petScale - scale) < 0.025 {
                        Label("\(Int(scale * 100))%", systemImage: "checkmark")
                    } else {
                        Text("\(Int(scale * 100))%")
                    }
                }
            }
        }
        Menu("Brain") {
            Text(store.ollamaState.shortTitle)
            Text(store.settings.model)
            Divider()
            Button("Open Brain Settings") { openMainframe() }
        }
        Menu("Settings") {
            Button("Open Mainframe") { openMainframe() }
            Button("Hide Capri") { CompanionController.shared.hidePet() }
            Divider()
            Button("Quit Capri") { NSApp.terminate(nil) }
        }
    }

    private func openChat() {
        store.recordActivity()
        store.page = .companion
        store.isExpanded = true
    }

    private func openMainframe() {
        store.recordActivity()
        CompanionController.shared.openMainframe()
    }

    private func resizePanel(animated: Bool = true) {
        guard let panel else { return }
        let size = panelSize
        let frame = NSRect(x: panel.frame.origin.x, y: panel.frame.maxY - size.height, width: size.width, height: size.height)
        panel.setFrame(frame, display: true, animate: animated)
    }
}

private struct ChatPetView<MenuContent: View>: View {
    @ObservedObject var store: AppStore
    @ObservedObject var speech: SpeechInputManager
    var menu: MenuContent
    var openMainframe: () -> Void
    @FocusState private var inputFocused: Bool

    private let cyan = Color(hex: 0x00E7F4)
    private let magenta = Color(hex: 0xF62474)

    private var chatHeight: CGFloat {
        CGFloat(store.hasMetUser ? 620 : 520) + max(0, (CGFloat(store.petScale) - 1) * 342)
    }

    var body: some View {
        VStack(spacing: 7) {
            promptBar
            if store.hasMetUser { conversation.frame(height: 72) }
            Spacer(minLength: 0)
            CharacterPhoto(wake: store.settings.wake)
                .frame(width: 204 * CGFloat(store.petScale), height: 342 * CGFloat(store.petScale))
                .contentShape(Rectangle())
                .contextMenu { menu }
            Spacer(minLength: 0)
            toolBar
        }
        .padding(.horizontal, 26).padding(.top, 42).padding(.bottom, 16)
        .frame(width: 380, height: chatHeight)
        .onAppear { inputFocused = true }
    }

    private var promptBar: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1).fill(magenta).frame(width: 3, height: 23)
            Text("> you:").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(Color(hex: 0x8896A7))
            TextField(store.hasMetUser ? "" : "what should I call you?", text: $store.draft)
                .textFieldStyle(.plain).font(.system(size: 12, design: .monospaced)).foregroundStyle(.white)
                .focused($inputFocused).onSubmit(send)
        }
        .padding(.horizontal, 10).frame(height: 42)
        .background(Color.black)
        .clipShape(ChamferedBox(cut: 12))
        .overlay(ChamferedBox(cut: 12).stroke(cyan, lineWidth: 1.4))
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(store.messages.suffix(2)) { message in
                        ChatSpeechBubble(message: message, cyan: cyan, magenta: magenta).id(message.id)
                    }
                    if store.isSending {
                        HStack(spacing: 6) {
                            Text("< capri:").font(.system(size: 9, design: .monospaced)).foregroundStyle(magenta)
                            ProgressView().controlSize(.mini).tint(cyan)
                            Text("thinking locally…").font(.system(size: 9)).foregroundStyle(Color(hex: 0x9BA4BA))
                        }
                    }
                    if !store.statusMessage.isEmpty && (store.ollamaState != .connected || store.statusMessage.localizedCaseInsensitiveContains("failed")) {
                        Text(store.statusMessage).font(.system(size: 8)).foregroundStyle(Color(hex: 0xFFC76B))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 7).padding(.vertical, 3)
            }
            .frame(height: 70).scrollIndicators(.hidden)
            .onChange(of: store.messages.count) { _ in
                if let last = store.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    private var toolBar: some View {
        HStack(spacing: 0) {
            Button(action: openMainframe) {
                Image(systemName: "pencil").font(.system(size: 15, weight: .medium)).foregroundStyle(Color(hex: 0xD6DCE7))
                    .frame(width: 43, height: 32)
            }.buttonStyle(.plain).help("Mainframe")
            Rectangle().fill(Color(hex: 0x46505D)).frame(width: 1, height: 19)
            Button {
                if store.settings.voiceInput { speech.toggle() }
                else { openMainframe() }
            } label: {
                Image(systemName: speech.isRecording ? "waveform" : "mic.fill")
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(speech.isRecording ? cyan : Color(hex: 0xD6DCE7))
                    .frame(width: 43, height: 32)
            }.buttonStyle(.plain).help(store.settings.voiceInput ? "Toggle microphone" : "Enable voice in Mainframe")
        }
        .padding(.horizontal, 2).background(Color(hex: 0x11151C), in: Capsule())
        .overlay(Capsule().stroke(Color(hex: 0x444B55), lineWidth: 1))
    }

    private func send() {
        if !store.hasMetUser {
            let name = store.draft
            store.draft = ""
            store.finishIntro(name: name)
        } else {
            store.sendDraft()
        }
        inputFocused = true
    }
}

private struct ChatSpeechBubble: View {
    let message: ChatMessage
    let cyan: Color
    let magenta: Color

    private var isUser: Bool { message.role == .user }
    private var accent: Color { isUser ? cyan : magenta }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(isUser ? "> you:" : "CAPRI:")
                    .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(accent)
                Text(message.text)
                    .font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(Color(hex: 0xE8EDF0))
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Color.black.opacity(0.94), in: ChamferedBox(cut: 9))
            .overlay(ChamferedBox(cut: 9).stroke(cyan, lineWidth: 1.15))
            .overlay(alignment: .leading) { Rectangle().fill(accent).frame(width: 2).padding(.vertical, 7) }
            if !isUser {
                ChatBubbleTail().fill(Color.black.opacity(0.94)).frame(width: 18, height: 9).padding(.leading, 65)
                    .overlay(alignment: .bottom) {
                        ChatBubbleTail().stroke(cyan, lineWidth: 1).frame(width: 18, height: 9).padding(.leading, 65)
                    }
                    .offset(y: -1)
            }
        }
    }
}

private struct ChatBubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX + 2, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private struct ChamferedBox: Shape {
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

struct CharacterPhoto: View {
    var wake: WakePreset = .softBoot
    @State private var floating = false
    @State private var awake = false
    @State private var glitching = false
    @State private var shatterBurst = false
    @State private var orbitPulse = false
    @State private var orbitRotation = 0.0
    @State private var characterScale = 1.0
    @State private var jackOffset = CGSize.zero
    @State private var jackRotation = 0.0
    @State private var glitchTask: Task<Void, Never>?
    @State private var introTask: Task<Void, Never>?

    private let cyan = Color(hex: 0x00E7F4)
    private let magenta = Color(hex: 0xF62474)

    private var sourceImage: Image {
        guard let url = Bundle.main.url(forResource: "capri-main", withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return Image(systemName: "bird.fill") }
        return Image(nsImage: image)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if wake == .orbitSync {
                    Circle()
                        .trim(from: 0.06, to: 0.78)
                        .stroke(AngularGradient(colors: [cyan.opacity(0.08), cyan, magenta.opacity(0.85), cyan.opacity(0.08)], center: .center), style: StrokeStyle(lineWidth: 1.25, lineCap: .round, dash: [4, 7]))
                        .frame(width: geometry.size.width * 0.64, height: geometry.size.height * 0.72)
                        .rotationEffect(.degrees(orbitRotation))
                        .scaleEffect(orbitPulse ? 1 : 0.72)
                        .opacity(orbitPulse ? 0.82 : 0)
                        .shadow(color: cyan.opacity(0.55), radius: 6)
                    Circle()
                        .stroke(cyan.opacity(0.22), lineWidth: 0.8)
                        .frame(width: geometry.size.width * 0.50, height: geometry.size.height * 0.60)
                        .scaleEffect(orbitPulse ? 1.12 : 0.8)
                        .opacity(orbitPulse ? 0.45 : 0)
                }

                if wake == .prismWake && shatterBurst {
                    shatterBand(top: 0.08, bottom: 0.30, x: -12, y: -3, tint: cyan, in: geometry.size)
                    shatterBand(top: 0.30, bottom: 0.56, x: 11, y: 2, tint: magenta, in: geometry.size)
                    shatterBand(top: 0.56, bottom: 0.79, x: -8, y: 1, tint: cyan, in: geometry.size)
                    shatterBand(top: 0.79, bottom: 0.98, x: 9, y: -2, tint: magenta, in: geometry.size)
                }

                sourceImage.resizable().scaledToFit()
                    .opacity(awake ? 1 : 0)

                if wake == .prismWake && glitching {
                    sourceImage.resizable().scaledToFit()
                        .colorMultiply(cyan).blendMode(.screen)
                        .offset(x: 4).opacity(0.42)
                    sourceImage.resizable().scaledToFit()
                        .colorMultiply(magenta).blendMode(.screen)
                        .offset(x: -3).opacity(0.28)
                    VStack(spacing: 0) {
                        Color.white.opacity(0.52).frame(height: 1)
                        Spacer(minLength: 0)
                        Color.cyan.opacity(0.36).frame(height: 1)
                    }
                    .padding(.horizontal, geometry.size.width * 0.12)
                    .padding(.vertical, geometry.size.height * 0.22)
                    .transition(.opacity)
                    .allowsHitTesting(false)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .offset(x: jackOffset.width,
                    y: jackOffset.height + (awake ? (floating ? -3.5 : 2) : 18))
            .rotationEffect(.degrees(jackRotation + (wake == .orbitSync && floating ? 0.55 : 0)))
            .scaleEffect(characterScale)
        }
        .clipped()
        .onAppear {
            playIntro()
        }
        .onChange(of: wake) { _ in playIntro() }
        .onDisappear {
            introTask?.cancel(); introTask = nil
            glitchTask?.cancel(); glitchTask = nil
        }
    }

    @ViewBuilder
    private func shatterBand(top: CGFloat, bottom: CGFloat, x: CGFloat, y: CGFloat, tint: Color, in size: CGSize) -> some View {
        GeometryReader { proxy in
            sourceImage.resizable().scaledToFit()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .offset(x: shatterBurst ? x : 0, y: shatterBurst ? y : 0)
                .colorMultiply(tint)
                .blendMode(.screen)
                .mask(alignment: .top) {
                    Rectangle()
                        .frame(height: proxy.size.height * (bottom - top))
                        .offset(y: proxy.size.height * top)
                }
                .opacity(shatterBurst ? 0.76 : 0)
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    private func playIntro() {
        introTask?.cancel()
        glitchTask?.cancel()
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            floating = false
            awake = false
            glitching = false
            shatterBurst = false
            orbitPulse = false
            orbitRotation = 0
            jackOffset = wake == .softBoot ? CGSize(width: 32, height: -10) : .zero
            jackRotation = wake == .softBoot ? -13 : 0
            characterScale = wake == .softBoot ? 0.86 : (wake == .orbitSync ? 0.78 : 0.94)
        }

        introTask = Task { @MainActor in
            switch wake {
            case .softBoot:
                withAnimation(.easeOut(duration: 0.22)) { awake = true }
                try? await Task.sleep(for: .milliseconds(55))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.30, dampingFraction: 0.48)) {
                    jackOffset = CGSize(width: -10, height: 2)
                    jackRotation = 8
                    characterScale = 1.04
                }
                try? await Task.sleep(for: .milliseconds(285))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.24, dampingFraction: 0.58)) {
                    jackOffset = CGSize(width: 4, height: 0)
                    jackRotation = -3
                    characterScale = 0.98
                }
                try? await Task.sleep(for: .milliseconds(190))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
                    jackOffset = .zero
                    jackRotation = 0
                    characterScale = 1
                }

            case .prismWake:
                shatterBurst = true
                withAnimation(.easeOut(duration: 0.24)) { characterScale = 1 }
                try? await Task.sleep(for: .milliseconds(145))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.22, dampingFraction: 0.60)) {
                    awake = true
                    shatterBurst = false
                }
                try? await Task.sleep(for: .milliseconds(160))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.12)) { glitching = true }
                try? await Task.sleep(for: .milliseconds(95))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.16)) { glitching = false }

            case .orbitSync:
                withAnimation(.easeOut(duration: 0.34)) { orbitPulse = true }
                withAnimation(.easeOut(duration: 0.28)) { awake = true; characterScale = 1 }
                withAnimation(.easeOut(duration: 1.20)) { orbitRotation = 360 }
                try? await Task.sleep(for: .milliseconds(1050))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.38)) { orbitPulse = false }
            }

            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: wake == .orbitSync ? 1.8 : 2.15).repeatForever(autoreverses: true)) {
                floating = true
            }
        }

        if wake == .prismWake {
            glitchTask = Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(Double.random(in: 5...9)))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeInOut(duration: 0.10)) { glitching = true; shatterBurst = true }
                    try? await Task.sleep(for: .milliseconds(85))
                    withAnimation(.easeOut(duration: 0.16)) { glitching = false; shatterBurst = false }
                }
            }
        }
    }
}

struct SignalMark: View {
    let color: Color
    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.5), lineWidth: 1)
            Circle().trim(from: 0.05, to: 0.68).stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            Circle().fill(color).frame(width: 3.5, height: 3.5)
        }.rotationEffect(.degrees(-42))
    }
}

private struct WindowAccessor: NSViewRepresentable {
    var onResolve: (NSWindow?) -> Void
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { onResolve(view.window) }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { onResolve(nsView.window) }
    }
}
