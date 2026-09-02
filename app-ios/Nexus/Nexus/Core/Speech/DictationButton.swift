import SwiftUI
import UIKit

// MARK: - Resting mic button
//
// The small circular mic shown in a composer at rest. Tapping it asks the
// composer to begin dictation (permission + state handled there).

struct MicCircle: View {
    var diameter: CGFloat = 32
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color.Nexus.surface2)
                .frame(width: diameter, height: diameter)
                .overlay(
                    Image(systemName: "mic")
                        .font(.system(size: diameter * 0.44, weight: .medium))
                        .foregroundColor(.Nexus.muted)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dictation bar
//
// Full-width recording control (matches the reference UX): cancel (X) on the
// left, a live waveform in the middle, confirm (checkmark) on the right. Live
// transcript flows into the field above while this is shown.

struct DictationBar: View {
    @ObservedObject var speech: SpeechRecognizer
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onCancel()
            } label: {
                Circle()
                    .fill(Color.Nexus.surface2)
                    .frame(width: 34, height: 34)
                    .overlay(Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.Nexus.muted))
            }
            .buttonStyle(.plain)

            WaveformView(level: speech.audioLevel)
                .frame(maxWidth: .infinity)
                .frame(height: 34)

            Button {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onConfirm()
            } label: {
                Circle()
                    .fill(Color.Nexus.accent)
                    .frame(width: 34, height: 34)
                    .overlay(Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Live waveform
//
// A rolling bar-graph of recent audio levels — newest on the right. Idle audio
// shows as faint dots; speech drives the bars up. Purely cosmetic feedback.

struct WaveformView: View {
    let level: Float

    private static let barCount = 34
    @State private var history: [CGFloat] = Array(repeating: 0, count: WaveformView.barCount)

    var body: some View {
        GeometryReader { geo in
            let count = Self.barCount
            let spacing: CGFloat = 3
            let barWidth = max(2, (geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))
            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<count, id: \.self) { i in
                    Capsule()
                        .fill(history[i] > 0.04 ? Color.Nexus.ink : Color.Nexus.ghost)
                        .frame(
                            width: barWidth,
                            height: max(barWidth, history[i] * geo.size.height)
                        )
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .onChange(of: level) { _, newValue in
            var next = history
            next.removeFirst()
            next.append(CGFloat(newValue))
            withAnimation(.linear(duration: 0.08)) { history = next }
        }
    }
}
