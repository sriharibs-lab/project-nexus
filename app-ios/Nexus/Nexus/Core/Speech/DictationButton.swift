import SwiftUI
import UIKit

/// A circular mic button that dictates into a bound text field.
///
/// Tap to start (requests mic + speech permission on first use); the live
/// transcript is merged onto whatever text was already there. Tap again — or
/// stop speaking — to end. Recording state is a filled plum circle with a
/// gentle pulsing ring. Drops into any composer in place of a static mic glyph.
struct DictationButton: View {
    @Binding var text: String
    var diameter: CGFloat = 32

    @StateObject private var speech = SpeechRecognizer()
    @State private var baseText = ""
    @State private var pulse = false

    var body: some View {
        Button(action: toggle) {
            ZStack {
                Circle()
                    .fill(speech.isRecording ? Color.Nexus.accent : Color.Nexus.surface2)
                    .frame(width: diameter, height: diameter)

                if speech.isRecording {
                    Circle()
                        .stroke(Color.Nexus.accent.opacity(0.5), lineWidth: 2)
                        .frame(width: diameter, height: diameter)
                        .scaleEffect(pulse ? 1.45 : 1.0)
                        .opacity(pulse ? 0 : 0.9)
                }

                Image(systemName: speech.isRecording ? "mic.fill" : "mic")
                    .font(.system(size: diameter * 0.44, weight: .medium))
                    .foregroundColor(speech.isRecording ? .white : .Nexus.muted)
            }
        }
        .buttonStyle(.plain)
        .onChange(of: speech.isRecording) { _, recording in
            if recording {
                withAnimation(.easeOut(duration: 1.0).repeatForever(autoreverses: false)) { pulse = true }
            } else {
                pulse = false
            }
        }
        .onChange(of: speech.transcript) { _, transcript in
            guard speech.isRecording else { return }
            let sep = baseText.isEmpty ? "" : " "
            text = transcript.isEmpty ? baseText : baseText + sep + transcript
        }
        .onDisappear { speech.stop() }
    }

    private func toggle() {
        if speech.isRecording {
            speech.stop()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }
        Task {
            guard await speech.requestAuthorization() else { return }
            baseText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            speech.start()
        }
    }
}
