import SwiftUI
import UIKit

// MARK: - Create tab (artifact studio)
//
// Ask · Create · Sources (IA revision 2026-07-10). Four creation actions, all
// live: Audio overview (Fireworks script → Deepgram Aura-2 → Supabase
// Storage), Infographic (grounded spec rendered natively), Poster (FLUX image
// + native headline) and Quiz. "Report" was retired 2026-10-09; existing
// `paper` artifacts stay readable. See api/app/routers/artifacts.py.

enum ArtifactKind: String, CaseIterable, Identifiable {
    case audio, info, poster, quiz, paper
    var id: String { rawValue }

    /// Kinds offered in the studio grid (paper is legacy: read-only).
    static let creatable: [ArtifactKind] = [.audio, .info, .poster, .quiz]

    var label: String {
        switch self {
        case .audio:  return "Audio overview"
        case .info:   return "Infographic"
        case .poster: return "Poster"
        case .quiz:   return "Quiz me"
        case .paper:  return "Report"
        }
    }

    /// One-line promise under the label on the studio card.
    var blurb: String {
        switch self {
        case .audio:  return "A narrated walk-through to play on the go."
        case .info:   return "Key figures and moments, from your sources."
        case .poster: return "A striking visual with a headline that fits."
        case .quiz:   return "Five quick questions to check what stuck."
        case .paper:  return "A written briefing."
        }
    }

    var icon: String {
        switch self {
        case .audio:  return "waveform"
        case .info:   return "chart.bar.xaxis"
        case .poster: return "photo.artframe"
        case .quiz:   return "checkmark.circle"
        case .paper:  return "doc.text"
        }
    }

    /// Tinted tile per kind (one faint wash + one fg; mirrors the Sources palette).
    var tileBackground: Color {
        switch self {
        case .audio:  return Color.adaptive("#EFE9F8", "#2E2545")
        case .info:   return Color.adaptive("#F0F7EE", "#1F2E22")
        case .poster: return Color.adaptive("#FCF0EE", "#3A2320")
        case .quiz:   return Color.adaptive("#FDF5E8", "#3A2E18")
        case .paper:  return Color.adaptive("#EEF3FB", "#1F2A38")
        }
    }
    var tileForeground: Color {
        switch self {
        case .audio:  return Color(hex: "#7054AB")
        case .info:   return Color(hex: "#4A8A5C")
        case .poster: return Color(hex: "#C25A47")
        case .quiz:   return Color(hex: "#B8862A")
        case .paper:  return Color(hex: "#4A7ABB")
        }
    }

    /// Backend `kind` for the generate endpoint.
    var backendKind: String { rawValue }

    /// Match a server artifact's kind string back to a UI kind.
    static func from(_ raw: String) -> ArtifactKind? { ArtifactKind(rawValue: raw) }
}

struct CreateTabView: View {
    let collection: NexusCollection
    let items: [Item]

    @State private var artifacts: [Artifact] = []
    @State private var didLoad = false
    @State private var selected: Artifact?
    @State private var wizardKind: ArtifactKind?

    #if DEBUG
    init(collection: NexusCollection, items: [Item], previewArtifacts: [Artifact]? = nil) {
        self.collection = collection
        self.items = items
        if let previewArtifacts {
            _artifacts = State(initialValue: previewArtifacts)
            _didLoad = State(initialValue: true)
        }
    }
    #endif

    private var readyCount: Int { items.filter { $0.ingestStatus == .completed }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NexusSpacing.lg) {
                header

                LazyVGrid(columns: [GridItem(.flexible(), spacing: NexusSpacing.md), GridItem(.flexible())], spacing: NexusSpacing.md) {
                    ForEach(ArtifactKind.creatable) { kind in
                        CreateCard(kind: kind) {
                            Haptics.impact(.light)
                            wizardKind = kind
                        }
                    }
                }

                VStack(alignment: .leading, spacing: NexusSpacing.sm) {
                    Text("YOUR CREATIONS")
                        .font(.Nexus.overline)
                        .foregroundColor(.Nexus.ghost)
                        .kerning(NexusKerning.wide)
                        .padding(.top, NexusSpacing.xs)

                    if artifacts.isEmpty {
                        if didLoad { emptyCreations }
                    } else {
                        ForEach(artifacts) { artifact in
                            Button { selected = artifact } label: {
                                ArtifactRow(artifact: artifact)
                            }
                            .buttonStyle(.plain)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
            }
            .padding(.horizontal, NexusSpacing.sideGutter)
            .padding(.top, NexusSpacing.lg)
            .padding(.bottom, NexusSpacing.xl)
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.8), value: artifacts)
        .task { await loadIfNeeded() }
        .sheet(item: $selected) { artifact in
            ArtifactDetailView(artifact: artifact, collectionName: collection.name) { deleted in
                artifacts.removeAll { $0.id == deleted.id }
            }
        }
        .sheet(item: $wizardKind) { kind in
            ArtifactWizardView(kind: kind, collection: collection, readyCount: readyCount) { created in
                artifacts.insert(created, at: 0)
                selected = created
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.xs) {
            Text("CREATE")
                .font(.Nexus.overline)
                .foregroundColor(.Nexus.ghost)
                .kerning(NexusKerning.wide)
            Text("Turn this collection into something new.")
                .font(.Nexus.bodySmall)
                .foregroundColor(.Nexus.muted)
        }
    }

    /// Empty state for the creations list: fills the fold with intent, not air.
    private var emptyCreations: some View {
        VStack(spacing: 10) {
            EchoMark(color: .Nexus.ghost, size: 30)
            Text("Nothing made yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.Nexus.ink)
            Text(readyCount == 0
                 ? "Once a source finishes reading, everything above lights up."
                 : "Start with an audio overview — it's the fastest way in.")
                .font(.system(size: 13.5))
                .foregroundColor(.Nexus.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28).padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                .foregroundColor(.Nexus.border)
        )
    }

    // MARK: Data

    private func loadIfNeeded() async {
        guard !didLoad else { return }
        do {
            let loaded = try await APIClient.shared.fetchArtifacts(in: collection.id)
            await MainActor.run { artifacts = loaded; didLoad = true }
        } catch {
            await MainActor.run { didLoad = true }
        }
    }
}

// MARK: - Creation card

private struct CreateCard: View {
    let kind: ArtifactKind
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: kind.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(kind.tileForeground)
                    .frame(width: 36, height: 36)
                    .background(kind.tileBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(kind.label)
                        .font(.system(size: 15, weight: .semibold))
                        .kerning(-0.2)
                        .foregroundColor(.Nexus.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(kind.blurb)
                        .font(.system(size: 12.5))
                        .foregroundColor(.Nexus.muted)
                        .lineSpacing(1.5)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .padding(14)
            .background(Color.Nexus.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: NexusRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NexusRadius.lg, style: .continuous)
                    .stroke(Color.Nexus.border, lineWidth: NexusBorder.hair)
            )
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? NexusScale.pressLight : 1)
        .animation(NexusAnimation.press, value: pressed)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressed = $0 }, perform: {})
    }
}

// MARK: - Artifact row (list card)

private struct ArtifactRow: View {
    let artifact: Artifact

    private var kind: ArtifactKind { ArtifactKind.from(artifact.kind) ?? .paper }

    private var subtitle: String {
        let c = artifact.content
        switch artifact.kind {
        case "quiz":
            let n = c?.questions?.count ?? 0
            return "Quiz · \(n) question\(n == 1 ? "" : "s")"
        case "paper":
            let sections = c?.outline?.count ?? 0
            return sections > 0 ? "Report · \(sections) sections" : "Report"
        case "info":
            switch c?.layout {
            case "timeline":   return "Infographic · timeline"
            case "comparison": return "Infographic · comparison"
            default:           return "Infographic · numbers"
            }
        case "audio":
            var parts = ["Audio"]
            if let d = c?.durationS, d > 0 { parts.append("\(max(1, Int((Double(d) / 60).rounded()))) min") }
            if let v = c?.voice, !v.isEmpty { parts.append(v.prefix(1).uppercased() + v.dropFirst()) }
            return parts.joined(separator: " · ")
        case "poster":
            if let s = c?.style, !s.isEmpty { return "Poster · \(s)" }
            return "Poster"
        default:
            return ""
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(kind.tileBackground)
                    .frame(width: 42, height: 42)
                Image(systemName: kind.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(kind.tileForeground)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(artifact.title)
                    .font(.system(size: 15, weight: .semibold))
                    .kerning(-0.2)
                    .foregroundColor(.Nexus.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.system(size: 12.5))
                    .foregroundColor(.Nexus.faint)
            }
            Spacer(minLength: 0)
            Image(systemName: artifact.kind == "audio" ? "play.circle.fill" : "chevron.right")
                .font(.system(size: artifact.kind == "audio" ? 22 : 13, weight: .semibold))
                .foregroundColor(artifact.kind == "audio" ? .Nexus.accent : .Nexus.ghost)
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
        .background(Color.Nexus.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 7, x: 0, y: 2)
    }
}

// MARK: - Artifact detail (routes by kind)

private struct ArtifactDetailView: View {
    let artifact: Artifact
    var collectionName: String? = nil
    var onDelete: (Artifact) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var shareImage: Image?
    @State private var confirmDelete = false
    @StateObject private var poster = RemoteImageLoader()

    private var navTitle: String {
        (ArtifactKind.from(artifact.kind) ?? .paper).label
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.Nexus.pageBackground.ignoresSafeArea()
                content
            }
            .task {
                if artifact.kind == "poster" { await poster.load(artifact.content?.imageUrl) }
                renderShareImage()
            }
            .onChange(of: poster.image) { _, _ in renderShareImage() }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SheetCloseButton { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if let shareImage {
                            ShareLink(item: shareImage, preview: SharePreview(artifact.title, image: shareImage)) {
                                Label("Share as image", systemImage: "photo")
                            }
                        }
                        if artifact.kind == "audio", let s = artifact.content?.audioUrl, let url = URL(string: s) {
                            ShareLink(item: url) { Label("Share audio", systemImage: "square.and.arrow.up") }
                        } else {
                            ShareLink(item: shareText) {
                                Label(hasImage ? "Share as text" : "Share", systemImage: "square.and.arrow.up")
                            }
                        }
                        Button {
                            UIPasteboard.general.string = shareText
                            Haptics.notify(.success)
                        } label: { Label(artifact.kind == "audio" ? "Copy transcript" : "Copy", systemImage: "doc.on.doc") }
                        Divider()
                        Button(role: .destructive) { confirmDelete = true } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.Nexus.ink)
                    }
                }
            }
            .alert("Delete this \(navTitle.lowercased())?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive) {
                    Task {
                        try? await APIClient.shared.deleteArtifact(id: artifact.id)
                        await MainActor.run { onDelete(artifact); dismiss() }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var hasImage: Bool { artifact.kind == "info" || artifact.kind == "poster" }

    /// Render the infographic / poster to a crisp image for sharing (what you
    /// share is exactly what you see). Runs on the main actor via .task.
    @MainActor
    private func renderShareImage() {
        guard let c = artifact.content else { return }
        let renderer: ImageRenderer<AnyView>
        switch artifact.kind {
        case "info":
            guard shareImage == nil else { return }
            renderer = ImageRenderer(content: AnyView(
                InfographicCard(title: c.title ?? artifact.title, subtitle: c.subtitle, content: c, collectionName: collectionName)
                    .frame(width: 360)
                    .padding(24)
                    .background(Color.Nexus.pageBackground)
            ))
        case "poster":
            guard let img = poster.image else { return }
            renderer = ImageRenderer(content: AnyView(
                PosterCard(image: img, headline: c.headline ?? artifact.title, subline: c.subline, collectionName: collectionName)
                    .frame(width: 540)
            ))
        default:
            return
        }
        renderer.scale = 3
        if let ui = renderer.uiImage { shareImage = Image(uiImage: ui) }
    }

    /// Plain-text rendering for Copy / Share.
    private var shareText: String {
        let c = artifact.content
        switch artifact.kind {
        case "paper":
            return c?.markdown ?? artifact.title
        case "audio":
            return c?.script ?? artifact.title
        case "poster":
            var out = c?.headline ?? artifact.title
            if let s = c?.subline, !s.isEmpty { out += "\n" + s }
            if let u = c?.imageUrl { out += "\n" + u }
            return out
        case "info":
            guard let c else { return artifact.title }
            var out = (c.title ?? artifact.title) + "\n"
            if let sub = c.subtitle, !sub.isEmpty { out += sub + "\n" }
            out += "\n"
            if let h = c.hero { out += "\(h.value) — \(h.label)\n\n" }
            if let n = c.numbers { for x in n { out += "\(x.value) — \(x.label)\n" } }
            if let t = c.timeline { for x in t { out += "\(x.when): \(x.what)\n" } }
            if let cmp = c.comparison {
                out += "\(cmp.a) vs \(cmp.b)\n"
                for r in cmp.rows { out += "\(r.aspect): \(r.a) | \(r.b)\n" }
            }
            if let t = c.takeaway, !t.isEmpty { out += "\n\(t)\n" }
            return out
        default:
            // Quiz → readable text
            var out = artifact.title + "\n\n"
            for (i, q) in (c?.questions ?? []).enumerated() {
                out += "\(i + 1). \(q.q)\n"
                for (j, opt) in q.options.enumerated() {
                    out += "   \(Character(UnicodeScalar(65 + j)!)). \(opt)\n"
                }
                out += "\n"
            }
            return out
        }
    }

    @ViewBuilder
    private var content: some View {
        switch artifact.kind {
        case "quiz":
            if let questions = artifact.content?.questions, !questions.isEmpty {
                QuizPlayerView(questions: questions)
            } else { unavailable }
        case "paper":
            if let md = artifact.content?.markdown, !md.isEmpty {
                PaperReaderView(markdown: md)
            } else { unavailable }
        case "info":
            if artifact.content?.layout != nil {
                InfographicView(artifact: artifact, collectionName: collectionName)
            } else { unavailable }
        case "audio":
            if artifact.content?.audioUrl != nil {
                AudioOverviewView(artifact: artifact, collectionName: collectionName)
            } else { unavailable }
        case "poster":
            if artifact.content?.imageUrl != nil {
                PosterView(artifact: artifact, image: poster.image, loading: poster.loading, collectionName: collectionName)
            } else { unavailable }
        default:
            unavailable
        }
    }

    private var unavailable: some View {
        VStack {
            Spacer()
            Text("This artifact couldn't be loaded.")
                .font(.Nexus.bodyMedium)
                .foregroundColor(.Nexus.muted)
            Spacer()
        }
    }
}

// MARK: - Paper reader (legacy artifacts)

private struct PaperReaderView: View {
    let markdown: String

    /// First H1 becomes the styled header title.
    private var headerTitle: String {
        for line in markdown.components(separatedBy: "\n") where line.hasPrefix("# ") {
            return String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        }
        return "Report"
    }

    /// Body markdown with the first H1 removed (it's rendered as the header).
    private var bodyMarkdown: String {
        var lines = markdown.components(separatedBy: "\n")
        if let i = lines.firstIndex(where: { $0.hasPrefix("# ") }) { lines.remove(at: i) }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("REPORT")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(1.4)
                    .foregroundColor(.Nexus.accent)
                    .padding(.bottom, 9)
                Text(headerTitle)
                    .font(.system(size: 25, weight: .bold))
                    .kerning(-0.5)
                    .foregroundColor(.Nexus.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 16)
                Rectangle()
                    .fill(Color.Nexus.hair)
                    .frame(height: 1)
                    .padding(.bottom, 18)

                AssistantMarkdown(content: bodyMarkdown)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.Nexus.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 5)
            .padding(.horizontal, NexusSpacing.sideGutter)
            .padding(.vertical, NexusSpacing.lg)
        }
    }
}

// MARK: - Quiz player (interactive)

private struct QuizPlayerView: View {
    let questions: [QuizQuestion]

    @State private var index = 0
    @State private var picked: Int?
    @State private var score = 0
    @State private var finished = false

    var body: some View {
        if finished {
            resultScreen
        } else {
            questionScreen
        }
    }

    private var current: QuizQuestion { questions[index] }

    private var questionScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NexusSpacing.lg) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("QUESTION \(index + 1) OF \(questions.count)")
                        .font(.system(size: 11, weight: .semibold))
                        .kerning(0.7)
                        .foregroundColor(.Nexus.faint)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.Nexus.surface2).frame(height: 4)
                            Capsule().fill(Color.Nexus.accent)
                                .frame(width: geo.size.width * CGFloat(index + 1) / CGFloat(questions.count), height: 4)
                        }
                    }
                    .frame(height: 4)
                }

                Text(current.q)
                    .font(.system(size: 19, weight: .semibold))
                    .kerning(-0.3)
                    .foregroundColor(.Nexus.ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    ForEach(Array(current.options.enumerated()), id: \.offset) { i, option in
                        OptionRow(
                            text: option,
                            state: optionState(i),
                            action: { pick(i) }
                        )
                        .disabled(picked != nil)
                    }
                }

                if picked != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(picked == current.answer ? "Correct" : "Not quite")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundColor(picked == current.answer ? .Nexus.success : .Nexus.destructive)
                        Text(current.why)
                            .font(.system(size: 14))
                            .foregroundColor(.Nexus.muted)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(13)
                    .background(Color.Nexus.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .transition(.opacity)

                    Button(action: next) {
                        Text(index + 1 == questions.count ? "See results" : "Next question")
                            .font(.system(size: 15.5, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.Nexus.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, NexusSpacing.sideGutter)
            .padding(.vertical, NexusSpacing.lg)
            .animation(.easeInOut(duration: 0.2), value: picked)
        }
    }

    private var resultScreen: some View {
        VStack(spacing: NexusSpacing.md) {
            Spacer()
            Text("\(score)/\(questions.count)")
                .font(.system(size: 52, weight: .bold))
                .foregroundColor(.Nexus.accent)
            Text(scoreMessage)
                .font(.system(size: 16))
                .foregroundColor(.Nexus.muted)
            Button(action: restart) {
                Text("Try again")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.Nexus.accent)
                    .padding(.horizontal, 22).padding(.vertical, 12)
                    .overlay(Capsule().stroke(Color.Nexus.accent, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var scoreMessage: String {
        let pct = Double(score) / Double(questions.count)
        switch pct {
        case 1.0: return "Perfect — you know this cold."
        case 0.6...: return "Solid grasp of the material."
        default: return "Worth another read of the sources."
        }
    }

    private func optionState(_ i: Int) -> OptionRow.State {
        guard let picked else { return .idle }
        if i == current.answer { return .correct }
        if i == picked { return .wrong }
        return .dimmed
    }

    private func pick(_ i: Int) {
        guard picked == nil else { return }
        picked = i
        let correct = i == current.answer
        if correct { score += 1 }
        Haptics.notify(correct ? .success : .error)
    }

    private func next() {
        if index + 1 == questions.count {
            withAnimation { finished = true }
        } else {
            withAnimation { index += 1; picked = nil }
        }
    }

    private func restart() {
        withAnimation { index = 0; picked = nil; score = 0; finished = false }
    }
}

// MARK: - Create wizard (configure, then generate)

private struct ArtifactWizardView: View {
    let kind: ArtifactKind
    let collection: NexusCollection
    var readyCount: Int = 1
    let onCreated: (Artifact) -> Void
    @Environment(\.dismiss) private var dismiss

    // Quiz
    @State private var qCount = 1   // [3, 5, 10] → default 5
    @State private var qDiff = 1    // [easy, medium, hard] → default medium
    // Infographic
    @State private var iKind = 0    // [auto, numbers, timeline, comparison]
    // Audio
    @State private var aVoice = 0   // [thalia, orion, asteria, arcas]
    @State private var aLength = 1  // [short, standard, long]
    // Poster
    @State private var pStyle = 0   // [editorial, abstract, photo, illustration]
    // Shared steer (info + poster)
    @State private var instructions = ""
    @FocusState private var instructionsFocused: Bool

    @State private var generating = false
    @State private var error: String?

    private let counts = [3, 5, 10]
    private let diffVals = ["easy", "medium", "hard"]
    private let infoVals = ["auto", "numbers", "timeline", "comparison"]
    private let voiceVals = ["thalia", "orion", "asteria", "arcas"]
    private let voiceNames = ["Thalia", "Orion", "Asteria", "Arcas"]
    private let lengthVals = ["short", "standard", "long"]
    private let styleVals = ["editorial", "abstract", "photo", "illustration"]

    var body: some View {
        NavigationStack {
            // Native inset-grouped Form on the page background. Segmented
            // Pickers are real UISegmentedControls — no custom pills.
            Form {
                switch kind {
                case .quiz:
                    Section("Number of questions") {
                        Picker("Number of questions", selection: $qCount) {
                            ForEach(counts.indices, id: \.self) { Text("\(counts[$0])").tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                    Section {
                        Picker("Difficulty", selection: $qDiff) {
                            Text("Easy").tag(0); Text("Medium").tag(1); Text("Hard").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    } header: {
                        Text("Difficulty")
                    } footer: {
                        Text("Questions are generated from this collection's sources.")
                    }

                case .info:
                    Section {
                        Picker("Type", selection: $iKind) {
                            Text("Auto").tag(0); Text("Numbers").tag(1); Text("Timeline").tag(2); Text("Compare").tag(3)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    } header: {
                        Text("Type")
                    } footer: {
                        Text("Auto picks the layout that fits your sources. Every figure comes from the sources — nothing is invented.")
                    }
                    instructionsSection(placeholder: "e.g. Focus on costs, compare the two approaches…")

                case .audio:
                    Section {
                        Picker("Voice", selection: $aVoice) {
                            ForEach(voiceNames.indices, id: \.self) { Text(voiceNames[$0]).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    } header: {
                        Text("Voice")
                    }
                    Section {
                        Picker("Length", selection: $aLength) {
                            Text("Short").tag(0); Text("Standard").tag(1); Text("Long").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    } header: {
                        Text("Length")
                    } footer: {
                        Text(["About 2 minutes.", "About 3 minutes.", "About 5 minutes."][aLength] + " One narrator walks through what your sources say and where they disagree.")
                    }

                case .poster:
                    Section {
                        Picker("Style", selection: $pStyle) {
                            Text("Editorial").tag(0); Text("Abstract").tag(1); Text("Photo").tag(2); Text("Drawn").tag(3)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    } header: {
                        Text("Style")
                    } footer: {
                        Text("The image is generated; the headline is written from your sources and set on top, so the type is always crisp.")
                    }
                    instructionsSection(placeholder: "e.g. Night-time city, warm palette, one bold shape…")

                case .paper:
                    EmptyView()
                }

                if readyCount == 0 {
                    Section {
                        Label("Add and finish reading at least one source first.", systemImage: "exclamationmark.circle")
                            .font(.system(size: 13.5))
                            .foregroundColor(.Nexus.muted)
                    }
                }

                if let error {
                    Section {
                        Text(error)
                            .font(.system(size: 13.5))
                            .foregroundColor(.Nexus.destructive)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.Nexus.pageBackground)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(kind.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SheetCloseButton { dismiss() }.disabled(generating)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { instructionsFocused = false }
                }
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(generating)
    }

    @ViewBuilder
    private func instructionsSection(placeholder: String) -> some View {
        Section {
            TextField(placeholder, text: $instructions, axis: .vertical)
                .lineLimit(2...4)
                .focused($instructionsFocused)
                .onChange(of: instructions) { _, v in
                    if v.count > 300 { instructions = String(v.prefix(300)) }
                }
        } header: {
            Text("Instructions")
        } footer: {
            Text("Optional. Anything specific you want it to focus on.")
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        Group {
            if generating {
                HStack(spacing: 10) {
                    EchoPulseView().frame(width: 24, height: 24)
                    Text(generatingLabel)
                        .font(.system(size: 14.5))
                        .foregroundColor(.Nexus.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
            } else {
                Button(action: generate) {
                    Text("Generate").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.Nexus.accent)
                .controlSize(.large)
                .disabled(readyCount == 0)
                .padding(.horizontal, NexusSpacing.sideGutter)
                .padding(.vertical, 10)
            }
        }
        .background(.bar)
    }

    private var generatingLabel: String {
        switch kind {
        case .quiz:   return "Building your quiz…"
        case .info:   return "Drawing your infographic…"
        case .audio:  return "Writing the script, then recording — about a minute…"
        case .poster: return "Painting your poster — about 30 seconds…"
        case .paper:  return "Writing…"
        }
    }

    private func generate() {
        Haptics.impact(.medium)
        instructionsFocused = false
        generating = true
        error = nil
        let steer = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        var opts = ArtifactOptions()
        switch kind {
        case .quiz:   opts = ArtifactOptions(numQuestions: counts[qCount], difficulty: diffVals[qDiff])
        case .info:   opts = ArtifactOptions(infoKind: infoVals[iKind], instructions: steer.isEmpty ? nil : steer)
        case .audio:  opts = ArtifactOptions(length: lengthVals[aLength], voice: voiceVals[aVoice])
        case .poster: opts = ArtifactOptions(style: styleVals[pStyle], instructions: steer.isEmpty ? nil : steer)
        case .paper:  opts = ArtifactOptions()
        }
        Task {
            do {
                let created = try await APIClient.shared.createArtifact(kind: kind.backendKind, options: opts, in: collection.id)
                await MainActor.run { onCreated(created); dismiss() }
            } catch {
                await MainActor.run {
                    generating = false
                    self.error = friendly(error)
                }
            }
        }
    }

    private func friendly(_ e: Error) -> String {
        if case APIError.serverError(422) = e {
            return "Add and process at least one source before creating this."
        }
        return "Couldn't create that just now. Please try again."
    }
}

#if DEBUG
enum CreateWizardPreview {
    @MainActor static func make(kind: ArtifactKind) -> some View {
        WizardPreviewHost(kind: kind)
    }
}

// Presents the wizard as a real sheet so the medium detent + drag indicator
// render in screenshots (the view alone wouldn't get the sheet chrome).
private struct WizardPreviewHost: View {
    let kind: ArtifactKind
    @State private var show = true
    var body: some View {
        ZStack {
            Color.Nexus.pageBackground.ignoresSafeArea()
            Text("Create").foregroundColor(.Nexus.faint)
        }
        .sheet(isPresented: $show) {
            ArtifactWizardView(kind: kind, collection: .previewSample) { _ in }
        }
    }
}

enum CreateTabPreview {
    @MainActor static func make(empty: Bool) -> some View {
        var audio = ArtifactContent(); audio.audioUrl = "https://example.com/a.mp3"; audio.durationS = 184; audio.voice = "thalia"; audio.words = 470
        var info = InfographicPreview.sample(layout: "numbers")
        info.title = "Picasso, in numbers"
        var poster = ArtifactContent(); poster.imageUrl = "https://example.com/p.jpg"; poster.headline = "Attention is the scarcest resource"; poster.style = "editorial"
        let list: [Artifact] = empty ? [] : [
            Artifact(id: UUID(), collectionId: UUID(), kind: "audio", title: "The attention economy, in three minutes", status: "ready", content: audio, model: nil, createdAt: ""),
            Artifact(id: UUID(), collectionId: UUID(), kind: "info", title: "Picasso, in numbers", status: "ready", content: info, model: nil, createdAt: ""),
            Artifact(id: UUID(), collectionId: UUID(), kind: "poster", title: "Attention is the scarcest resource", status: "ready", content: poster, model: nil, createdAt: ""),
        ]
        return NavigationStack {
            ZStack {
                NexusBackground()
                CreateTabView(collection: .previewSample, items: [], previewArtifacts: list)
            }
            .navigationTitle(NexusCollection.previewSample.name)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

enum AudioOverviewPreview {
    @MainActor static func make() -> some View {
        var c = ArtifactContent()
        c.audioUrl = "https://example.com/a.mp3"
        c.durationS = 184
        c.voice = "thalia"
        c.words = 470
        c.script = "Here's your Nexus overview of The attention economy. Across the six pieces you saved, one idea keeps surfacing: attention isn't just scarce, it's the product. Tristan Harris calls the feed a slot machine; Tim Wu traces the same logic back to the penny press. Where the sources disagree is on the fix. Two argue for regulation of recommender systems, while the Stratechery piece bets on paid subscriptions re-aligning incentives. The takeaway: the business model, not the design, is the thing to change."
        let a = Artifact(id: UUID(), collectionId: UUID(), kind: "audio", title: "The attention economy, in three minutes", status: "ready", content: c, model: nil, createdAt: "")
        return NavigationStack {
            ZStack {
                Color.Nexus.pageBackground.ignoresSafeArea()
                AudioOverviewView(artifact: a, collectionName: "The attention economy")
            }
            .navigationTitle("Audio overview").navigationBarTitleDisplayMode(.inline)
        }
    }
}
#endif

private struct OptionRow: View {
    enum State { case idle, correct, wrong, dimmed }
    let text: String
    let state: State
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(text)
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundColor(foreground)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if let icon {
                    Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundColor(foreground)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(border, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .opacity(state == .dimmed ? 0.5 : 1)
    }

    private var icon: String? {
        switch state {
        case .correct: return "checkmark.circle.fill"
        case .wrong:   return "xmark.circle.fill"
        default:       return nil
        }
    }
    private var foreground: Color {
        switch state {
        case .correct: return .Nexus.success
        case .wrong:   return .Nexus.destructive
        default:       return .Nexus.ink
        }
    }
    private var background: Color {
        switch state {
        case .correct: return Color.Nexus.success.opacity(0.10)
        case .wrong:   return Color.Nexus.destructive.opacity(0.08)
        default:       return Color.Nexus.cardBackground
        }
    }
    private var border: Color {
        switch state {
        case .correct: return Color.Nexus.success.opacity(0.4)
        case .wrong:   return Color.Nexus.destructive.opacity(0.4)
        default:       return Color.Nexus.hair
        }
    }
}
