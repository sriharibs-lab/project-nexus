import Combine
import Foundation
import UIKit

@MainActor
final class FeedbackViewModel: ObservableObject {
    // MARK: - Input state

    @Published var text: String = ""
    @Published var category: FeedbackCategory = .other
    @Published var includeScreenshot: Bool = true

    // MARK: - Screenshot

    @Published private(set) var screenshot: UIImage?

    // MARK: - Submission state

    @Published private(set) var isSubmitting = false
    @Published private(set) var didSubmit = false
    @Published var error: String?

    // MARK: - Category

    enum FeedbackCategory: String, CaseIterable, Identifiable {
        case bug        = "bug"
        case suggestion = "suggestion"
        case other      = "other"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .bug:        return "Bug"
            case .suggestion: return "Suggestion"
            case .other:      return "Other"
            }
        }
    }

    // MARK: - Screenshot capture

    /// Call this before navigating to FeedbackView so the screenshot
    /// captures the screen the user was on, not the feedback form itself.
    func captureScreenshot() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = scene.windows.first(where: { $0.isKeyWindow }) else {
            return
        }
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        screenshot = renderer.image { ctx in
            window.layer.render(in: ctx.cgContext)
        }
    }

    // MARK: - Computed device metadata

    private var appVersion: String? {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        if let v = version, let b = build { return "\(v) (\(b))" }
        return version
    }

    private var iosVersion: String {
        UIDevice.current.systemVersion
    }

    private var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        return machine ?? UIDevice.current.model
    }

    // MARK: - Submission

    var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    func submit() async {
        guard canSubmit else { return }

        isSubmitting = true
        error = nil
        defer { isSubmitting = false }

        // Encode screenshot as base64 data URI so it travels inline
        // without requiring a separate upload endpoint. The backend stores
        // it in a Text column (unlimited). Max ~1 MB before base64 expansion.
        var screenshotDataURI: String?
        if includeScreenshot, let img = screenshot {
            let compressed = img.jpegData(compressionQuality: 0.5)
            if let data = compressed {
                let b64 = data.base64EncodedString()
                screenshotDataURI = "data:image/jpeg;base64,\(b64)"
            }
        }

        let request = FeedbackRequest(
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            screenshotUrl: screenshotDataURI,
            category: category.rawValue,
            appVersion: appVersion,
            iosVersion: iosVersion,
            deviceModel: deviceModel
        )

        do {
            let _: FeedbackSubmitResponse = try await APIClient.shared.submitFeedback(request)
            didSubmit = true
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = "Submission failed. Please try again."
        }
    }
}
