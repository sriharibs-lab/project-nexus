import AVFoundation
import Combine
import Foundation
import Speech

/// Continuous live dictation via the Speech framework.
///
/// Recognition is CONTINUOUS and user-controlled: it does NOT stop on the first
/// pause. SFSpeechRecognizer finalizes an utterance after a silence and stops
/// delivering; we commit that text and immediately restart a fresh request on
/// the still-running audio engine, so "US … UK … relations" accumulates instead
/// of truncating at "US". Only stop()/cancel() end the session.
///
/// Publishes `transcript` (the running session text) and `audioLevel` (0–1, for
/// a live waveform). Defensive throughout — denial/unavailability/errors just
/// leave `isRecording` false, never a crash.
@MainActor
final class SpeechRecognizer: ObservableObject {
    @Published private(set) var transcript = ""
    @Published private(set) var isRecording = false
    @Published private(set) var audioLevel: Float = 0

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) ?? SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// Text finalized from prior utterances this session; the live partial is
    /// appended to it to form `transcript`.
    private var committed = ""

    var isAvailable: Bool { recognizer?.isAvailable ?? false }

    func requestAuthorization() async -> Bool {
        let speechOK = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
        guard speechOK else { return false }
        return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
        }
    }

    func start() {
        guard !isRecording, let recognizer, recognizer.isAvailable else { return }
        committed = ""
        transcript = ""
        audioLevel = 0

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.request?.append(buffer)
                let level = SpeechRecognizer.rms(buffer)
                Task { @MainActor in self?.audioLevel = level }
            }
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
            beginTask()
        } catch {
            cleanup()
        }
    }

    /// Stop and KEEP the transcript (checkmark).
    func stop() {
        guard isRecording else { return }
        cleanup()
    }

    /// Stop and DISCARD this session's transcript (X).
    func cancel() {
        guard isRecording else { return }
        cleanup()
        transcript = ""
        committed = ""
    }

    // MARK: - Internals

    private func beginTask() {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Server recognition handles long continuous dictation more reliably
        // than the on-device model; fall back to on-device only if required.
        request.requiresOnDeviceRecognition = false
        self.request = request

        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in self?.handle(result, error) }
        }
    }

    private func handle(_ result: SFSpeechRecognitionResult?, _ error: Error?) {
        guard isRecording else { return }

        if let result {
            let partial = result.bestTranscription.formattedString
            transcript = committed.isEmpty ? partial : committed + " " + partial
            if result.isFinal {
                committed = transcript
                restart()
            }
            return
        }

        // No result + error usually means the utterance finalized/errored after a
        // pause. Keep the session alive by restarting on the running engine.
        if error != nil {
            restart()
        }
    }

    private func restart() {
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        guard isRecording else { return }
        beginTask()
    }

    private func cleanup() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isRecording = false
        audioLevel = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Root-mean-square power of a buffer, mapped to a lively 0–1 range.
    private static func rms(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData?[0] else { return 0 }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<n { let s = data[i]; sum += s * s }
        let rms = (sum / Float(n)).squareRoot()
        // Map ~[-50dB, -10dB] → [0, 1] for a responsive waveform.
        let db = 20 * log10(max(rms, 1e-7))
        return min(max((db + 50) / 40, 0), 1)
    }
}
