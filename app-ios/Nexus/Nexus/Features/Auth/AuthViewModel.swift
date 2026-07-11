import AuthenticationServices
import Combine
import Foundation

// MARK: - Auth phase state machine

enum AuthPhase: Equatable {
    case idle                    // Landing — two options shown
    case emailEntry              // Magic link email input expanded
    case emailSending            // POST /auth/magic-link in flight
    case otpEntry(email: String) // Email sent; user enters 6-digit code
    case otpVerifying            // POST /auth/verify-otp in flight
    case signingIn               // POST /auth/provision in flight (Apple or after OTP)
    case done                    // Auth succeeded → RootView transitions to HomeView
    case error(String)           // Terminal error — user can retry

    static func == (lhs: AuthPhase, rhs: AuthPhase) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.emailEntry, .emailEntry),
             (.emailSending, .emailSending), (.otpVerifying, .otpVerifying),
             (.signingIn, .signingIn), (.done, .done):
            return true
        case let (.otpEntry(a), .otpEntry(b)): return a == b
        case let (.error(a), .error(b)): return a == b
        default: return false
        }
    }
}

// MARK: - ViewModel

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var phase: AuthPhase = .idle
    @Published var email: String = ""
    @Published var otpCode: String = ""
    /// Locked design (2026-07-09): errors show inline on the current screen,
    /// they never replace it. `.error` phase is retained in the enum but unused.
    @Published var inlineError: String?

    // MARK: - Email / magic link

    func showEmailEntry() {
        phase = .emailEntry
        email = ""
    }

    func cancelEmailEntry() {
        phase = .idle
        email = ""
    }

    func sendMagicLink() {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidEmail(trimmed) else {
            inlineError = "Enter a valid email address."
            return
        }
        inlineError = nil
        phase = .emailSending

        Task {
            do {
                try await APIClient.shared.sendMagicLink(email: trimmed)
                phase = .otpEntry(email: trimmed)
                otpCode = ""
            } catch {
                inlineError = friendlyError(error)
                phase = .idle
            }
        }
    }

    func verifyOTP() {
        guard case .otpEntry(let sentEmail) = phase else { return }
        let code = otpCode.trimmingCharacters(in: .whitespacesAndNewlines)
        // Supabase OTP length is configurable (6–10; this project sends 8)
        guard (6...10).contains(code.count) else {
            inlineError = "Enter the code from your email."
            return
        }
        inlineError = nil
        phase = .otpVerifying

        Task {
            do {
                let tokenResp = try await APIClient.shared.verifyOTP(email: sentEmail, token: code)
                await provisionSession(
                    accessToken: tokenResp.accessToken,
                    refreshToken: tokenResp.refreshToken,
                    userId: tokenResp.userUUID
                )
            } catch {
                inlineError = friendlyError(error)
                phase = .otpEntry(email: sentEmail)
            }
        }
    }

    func resendOTP() {
        guard case .otpEntry(let sentEmail) = phase else { return }
        email = sentEmail
        sendMagicLink()
    }

    func cancelOTPEntry() {
        phase = .idle
        otpCode = ""
        email = ""
    }

    // MARK: - Sign in with Apple

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = cred.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8)
            else {
                inlineError = "Apple sign-in failed. Please try again."
                return
            }
            inlineError = nil
            phase = .signingIn
            Task {
                do {
                    let resp = try await APIClient.shared.signInWithApple(identityToken: identityToken)
                    await provisionSession(
                        accessToken: resp.accessToken,
                        refreshToken: resp.refreshToken,
                        userId: resp.userUUID
                    )
                } catch {
                    inlineError = friendlyError(error)
                    phase = .idle
                }
            }

        case .failure(let err):
            // ASAuthorizationError.canceled (1001) — user dismissed the sheet; don't show error
            if (err as NSError).code == ASAuthorizationError.canceled.rawValue { return }
            inlineError = err.localizedDescription
        }
    }

    // MARK: - Retry

    func retryFromError() {
        phase = .idle
        otpCode = ""
        inlineError = nil
    }

    /// "Change email address" on the code screen — back to landing, email kept.
    func changeEmail() {
        phase = .idle
        otpCode = ""
        inlineError = nil
    }

    // MARK: - Dev bypass (debug builds only)

    #if DEBUG
    /// One-tap REAL session against the dev backend (fixed dev@nexus.test
    /// user). The old fake-token version created orphan users and 401'd on
    /// every API call — dev sessions must exercise the real auth path.
    func devBypass() {
        inlineError = nil
        Task {
            do {
                let resp = try await APIClient.shared.devLogin()
                AuthManager.shared.setSession(
                    accessToken: resp.accessToken,
                    refreshToken: resp.refreshToken,
                    userId: resp.userUUID,
                    email: "dev@nexus.test"
                )
            } catch {
                inlineError = "Dev login failed — is the local backend running?"
            }
        }
    }
    #endif

    // MARK: - Private

    private func provisionSession(accessToken: String, refreshToken: String, userId: UUID) async {
        // Provision and store session
        AuthManager.shared.setSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userId: userId
        )
        phase = .done
    }

    private func isValidEmail(_ email: String) -> Bool {
        // RFC-5322 simplified check — adequate for UI validation
        let parts = email.split(separator: "@", maxSplits: 1)
        guard parts.count == 2 else { return false }
        let local = parts[0], domain = String(parts[1])
        return !local.isEmpty && domain.contains(".") && domain.count > 2
    }

    private func friendlyError(_ error: Error) -> String {
        if let api = error as? APIError {
            switch api {
            case .networkError:   return "No internet connection. Check your network and try again."
            case .unauthorized:   return "Sign-in failed. Please try again."
            case .serverError:    return "Server error. Please try again in a moment."
            default:              return "Something went wrong. Please try again."
            }
        }
        return error.localizedDescription
    }
}
