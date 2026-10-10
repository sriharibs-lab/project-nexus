import SwiftUI
import AVFoundation
import Combine

// MARK: - Audio overview (solo narrator, Deepgram Aura-2 → Supabase Storage)
//
// A native player card: big play control on the Ember gradient, a scrubber,
// ±15s skips and a speed menu, with the full script underneath so the piece
// is readable as well as listenable. AVPlayer streams the public mp3 URL.

struct AudioOverviewView: View {
    let artifact: Artifact
    var collectionName: String? = nil

    @StateObject private var player = AudioPlayerController()
    @State private var showScript = false

    private var content: ArtifactContent { artifact.content ?? ArtifactContent() }

    var body: some View {
        ScrollView {
            VStack(spacing: NexusSpacing.standard) {
                playerCard
                scriptBlock
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .task {
            if let s = content.audioUrl, let url = URL(string: s) {
                player.load(url: url, fallbackDuration: Double(content.durationS ?? 0))
            }
        }
        .onDisappear { player.pause() }
    }

    // MARK: Player card

    private var playerCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(eyebrow)
                        .font(.system(size: 10.5, weight: .bold)).kerning(1.2)
                        .foregroundColor(.Nexus.accent)
                        .lineLimit(1)
                    Text(artifact.title)
                        .font(.system(size: 21, weight: .bold)).kerning(-0.4)
                        .foregroundColor(.Nexus.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(metaLine)
                        .font(.system(size: 13))
                        .foregroundColor(.Nexus.faint)
                }
                Spacer(minLength: 0)
                Group {
                    if player.isPlaying { EchoPulseView() } else { EchoMark(size: 36) }
                }
                .frame(width: 40, height: 40)
            }

            // Scrubber
            VStack(spacing: 6) {
                Slider(value: Binding(
                    get: { player.progress },
                    set: { player.scrub(to: $0) }
                ), in: 0...1, onEditingChanged: { editing in
                    player.setScrubbing(editing)
                })
                .tint(.Nexus.accent)
                HStack {
                    Text(Self.clock(player.current)).monospacedDigit()
                    Spacer()
                    Text("-" + Self.clock(max(0, player.duration - player.current))).monospacedDigit()
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(.Nexus.faint)
            }

            // Transport
            HStack {
                speedMenu
                Spacer()
                HStack(spacing: 26) {
                    Button { player.skip(-15) } label: {
                        Image(systemName: "gobackward.15")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.Nexus.ink)
                    }
                    .buttonStyle(.plain)
                    Button {
                        Haptics.impact(.light)
                        player.toggle()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [Color(hex: "#7054AB"), Color(hex: "#B8569C"), Color(hex: "#E8776A")],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 66, height: 66)
                                .shadow(color: Color(hex: "#7054AB").opacity(0.35), radius: 14, y: 6)
                            if player.isBuffering {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(.white)
                                    .offset(x: player.isPlaying ? 0 : 2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    Button { player.skip(15) } label: {
                        Image(systemName: "goforward.15")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.Nexus.ink)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                // Balance the speed menu's width so the play button stays centered.
                Color.clear.frame(width: 52, height: 1)
            }
        }
        .padding(18)
        .background(Color.Nexus.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.Nexus.hair, lineWidth: 1))
        .shadow(color: Color(hex: "#5E3F9E").opacity(0.10), radius: 16, y: 7)
    }

    private var speedMenu: some View {
        Menu {
            ForEach([0.8, 1.0, 1.25, 1.5, 2.0], id: \.self) { r in
                Button {
                    player.setRate(Float(r))
                } label: {
                    if player.rate == Float(r) { Label(Self.rateLabel(r), systemImage: "checkmark") }
                    else { Text(Self.rateLabel(r)) }
                }
            }
        } label: {
            Text(Self.rateLabel(Double(player.rate)))
                .font(.system(size: 12.5, weight: .bold)).monospacedDigit()
                .foregroundColor(.Nexus.ink)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.Nexus.surface2)
                .clipShape(Capsule())
                .frame(width: 52)
        }
    }

    // MARK: Script

    @ViewBuilder
    private var scriptBlock: some View {
        if let script = content.script, !script.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { showScript.toggle() }
                } label: {
                    HStack {
                        Text("TRANSCRIPT")
                            .font(.Nexus.overline).kerning(NexusKerning.wide)
                            .foregroundColor(.Nexus.ghost)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.Nexus.ghost)
                            .rotationEffect(.degrees(showScript ? 180 : 0))
                    }
                }
                .buttonStyle(.plain)
                Text(script)
                    .font(.system(size: 15))
                    .lineSpacing(6)
                    .foregroundColor(.Nexus.ink)
                    .lineLimit(showScript ? nil : 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.Nexus.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.Nexus.hair, lineWidth: 1))
        }
    }

    // MARK: Helpers

    private var eyebrow: String { "AUDIO OVERVIEW" }
    private var metaLine: String {
        var parts: [String] = []
        let d = player.duration > 0 ? player.duration : Double(content.durationS ?? 0)
        if d > 0 { parts.append("\(max(1, Int((d / 60).rounded()))) min") }
        if let v = content.voice, !v.isEmpty { parts.append(v.prefix(1).uppercased() + v.dropFirst()) }
        if let w = content.words, w > 0 { parts.append("\(w) words") }
        return parts.joined(separator: " · ")
    }
    static func clock(_ s: Double) -> String {
        let t = Int(s.rounded())
        return String(format: "%d:%02d", t / 60, t % 60)
    }
    static func rateLabel(_ r: Double) -> String {
        r == r.rounded() ? "\(Int(r))×" : String(format: "%.2g×", r)
    }
}

// MARK: - AVPlayer controller

@MainActor
final class AudioPlayerController: ObservableObject {
    @Published var isPlaying = false
    @Published var isBuffering = false
    @Published var progress: Double = 0     // 0…1
    @Published var current: Double = 0      // seconds
    @Published var duration: Double = 0     // seconds
    @Published var rate: Float = 1

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var statusCancellable: AnyCancellable?
    private var scrubbing = false
    private var pendingSeek: Double?

    func load(url: URL, fallbackDuration: Double) {
        guard player == nil else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        duration = fallbackDuration
        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        p.automaticallyWaitsToMinimizeStalling = true
        player = p
        isBuffering = true
        statusCancellable = item.publisher(for: \.status).receive(on: RunLoop.main).sink { [weak self] st in
            guard let self else { return }
            if st == .readyToPlay {
                self.isBuffering = false
                let d = item.duration.seconds
                if d.isFinite, d > 0 { self.duration = d }
            } else if st == .failed {
                self.isBuffering = false
            }
        }
        timeObserver = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] t in
            guard let self, !self.scrubbing else { return }
            let s = t.seconds
            guard s.isFinite else { return }
            self.current = s
            if self.duration > 0 { self.progress = min(1, s / self.duration) }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.isPlaying = false
            self.player?.seek(to: .zero)
            self.current = 0; self.progress = 0
        }
    }

    func toggle() { isPlaying ? pause() : play() }

    func play() {
        guard let player else { return }
        player.playImmediately(atRate: rate)
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func setRate(_ r: Float) {
        rate = r
        if isPlaying { player?.rate = r }
    }

    func skip(_ seconds: Double) {
        let target = min(max(0, current + seconds), max(duration, 0))
        seek(to: target)
    }

    /// Slider drives `progress` while the thumb is down; we seek on release.
    func scrub(to fraction: Double) {
        progress = fraction
        current = fraction * duration
        if scrubbing { pendingSeek = current } else { seek(to: current) }
    }

    func setScrubbing(_ on: Bool) {
        scrubbing = on
        if !on, let s = pendingSeek { pendingSeek = nil; seek(to: s) }
    }

    private func seek(to seconds: Double) {
        guard let player else { return }
        let t = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero)
        current = seconds
        if duration > 0 { progress = min(1, seconds / duration) }
    }

    deinit {
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }
}
