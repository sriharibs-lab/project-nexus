import AuthenticationServices
import SwiftUI

// MARK: - Auth screen
//
// LOCKED DESIGN (2026-07-09) — ported 1:1 from prototype /flows/login
// (Claude-iOS-style auth, Notion hero structure):
//   • Flat page, minimal brand color. Pill shapes for all buttons/inputs.
//   • Hero: Echo mark → bold "Your AI research companion." → grey account line.
//   • "Continue with Apple" = ink pill. Email is a TEXT BOX, not a button —
//     ghost text "Continue with email", centered; a dark send circle fades in
//     when the address is valid and becomes a spinner while sending.
//   • Code screen: bordered card, one-line title, light-purple (bloom) panel
//     with the email + centered pill Code field; "Change email address" link.
//   • Errors are inline text — they never replace the screen.
//   • Terms/Privacy disclaimer on every screen (stub links — PARKING_LOT.md).
//   • No separate sign-up: email OTP auto-creates the account.

struct AuthView: View {
    @StateObject private var vm = AuthViewModel()
    @State private var emailText = ""
    @State private var otpText = ""

    private var isCodePhase: Bool {
        if case .otpEntry = vm.phase { return true }
        if case .otpVerifying = vm.phase { return true }
        return false
    }

    var body: some View {
        ZStack {
            Color.Nexus.surface3.ignoresSafeArea()
            if isCodePhase {
                codeScreen.transition(.opacity)
            } else {
                landingScreen.transition(.opacity)
            }
        }
        .animation(.timingCurve(0.2, 0.8, 0.2, 1.0, duration: NexusDuration.slow), value: isCodePhase)
    }

    // MARK: - Landing

    private var landingScreen: some View {
        VStack(spacing: 0) {
            Spacer().frame(minHeight: 20)
            Spacer()

            // Hero — Notion structure: mark → bold tagline → grey account line
            VStack(spacing: 0) {
                EchoMark(color: Color.Nexus.accent, size: 64)
                Text("Your AI research companion.")
                    .font(.system(size: 28, weight: .bold))
                    .kerning(-0.7)
                    .foregroundColor(.Nexus.ink)
                    .padding(.top, 26)
                Text("Log in to your Nexus account")
                    .font(.system(size: 27, weight: .regular))
                    .kerning(-0.6)
                    .foregroundColor(.Nexus.faint)
                    .padding(.top, 2)
            }
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.8)
            .lineLimit(1)
            .padding(.horizontal, 20)

            Spacer()
            Spacer()

            // Auth stack
            VStack(spacing: 12) {
                appleButton
                emailBox

                if let error = vm.inlineError {
                    Text(error)
                        .font(.system(size: 13))
                        .kerning(-0.1)
                        .foregroundColor(.Nexus.destructive)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 20)

            disclaimer
                .padding(.top, 18)
                .padding(.horizontal, 34)

            #if DEBUG
            Button("Continue (dev)") { vm.devBypass() }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.Nexus.ghost)
                .padding(.top, 10)
            #endif

            Spacer().frame(height: NexusSpacing.safeBottom)
        }
        .animation(.easeInOut(duration: 0.2), value: vm.inlineError)
    }

    // Ink pill with the official (invisible) Apple button underneath for the
    // real auth sheet — visual layer matches the email box height exactly.
    private var appleButton: some View {
        ZStack {
            SignInWithAppleButton(.signIn) { req in
                req.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                vm.handleAppleSignIn(result: result)
            }
            .frame(height: 56)
            .opacity(0.011)
            .disabled(vm.phase == .signingIn)

            HStack(spacing: 9) {
                if vm.phase == .signingIn {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 19, weight: .medium))
                    Text("Continue with Apple")
                        .font(.system(size: 16.5, weight: .semibold))
                        .kerning(-0.2)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.Nexus.ink)
            .clipShape(Capsule())
            .allowsHitTesting(false)
        }
    }

    // The email text box — a field, not a button. Send circle appears on a
    // valid address; becomes a spinner while the code email is prepared.
    private var emailBox: some View {
        let sending = vm.phase == .emailSending
        let valid = isValidEmailShape(emailText)
        return HStack(spacing: 6) {
            TextField("", text: $emailText, prompt: emailPrompt)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.send)
                .onSubmit { submitEmail() }
                .font(.system(size: 16.5))
                .kerning(-0.2)
                .foregroundColor(.Nexus.ink)
                .multilineTextAlignment(emailText.isEmpty ? .center : .leading)
                .disabled(sending)
                .padding(.leading, 22)

            if valid || sending {
                Button(action: submitEmail) {
                    ZStack {
                        Circle().fill(Color.Nexus.ink).frame(width: 44, height: 44)
                        if sending {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.trailing, 6)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .frame(height: 56)
        .background(sending ? Color.Nexus.surface2 : Color.Nexus.cardBackground)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(sending ? Color.Nexus.surface2 : Color.Nexus.border, lineWidth: NexusBorder.base)
        )
        .animation(.easeInOut(duration: 0.2), value: valid || sending)
    }

    private var emailPrompt: Text {
        Text("Continue with email")
            .font(.system(size: 16.5))
            .foregroundColor(.Nexus.ghost)
    }

    private func submitEmail() {
        vm.email = emailText
        vm.sendMagicLink()
    }

    // Light structural check only — the VM validates properly on submit.
    private func isValidEmailShape(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "@", maxSplits: 1)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        let domain = String(parts[1])
        return domain.contains(".") && domain.count > 3 && !domain.hasSuffix(".")
    }

    // MARK: - Code screen

    private var codeScreen: some View {
        VStack(spacing: 0) {
            EchoMark(color: Color.Nexus.accent, size: 26)
                .padding(.top, 10)

            Spacer().frame(minHeight: 12)
            Spacer()

            codeCard
                .padding(.horizontal, 20)

            Spacer()
            Spacer()

            disclaimer
                .padding(.horizontal, 34)

            Spacer().frame(height: NexusSpacing.safeBottom)
        }
    }

    private var codeCard: some View {
        VStack(spacing: 18) {
            Text("Check your email to finish signing in")
                .font(.system(size: 18.5, weight: .semibold))
                .kerning(-0.4)
                .foregroundColor(.Nexus.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            // Light purple (bloom) panel
            VStack(spacing: 4) {
                Text("We sent an email to")
                    .font(.system(size: 14.5))
                    .kerning(-0.1)
                    .foregroundColor(.Nexus.muted)
                if case .otpEntry(let sentEmail) = vm.phase {
                    Text(sentEmail)
                        .font(.system(size: 16, weight: .semibold))
                        .kerning(-0.2)
                        .foregroundColor(.Nexus.ink)
                } else if case .otpVerifying = vm.phase {
                    Text(vm.email)
                        .font(.system(size: 16, weight: .semibold))
                        .kerning(-0.2)
                        .foregroundColor(.Nexus.ink)
                }

                codeField
                    .padding(.top, 12)

                if vm.phase == .otpVerifying {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.7)
                        Text("Verifying…")
                            .font(.system(size: 12.5))
                            .foregroundColor(.Nexus.muted)
                    }
                    .padding(.top, 10)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(Color.Nexus.bloom.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if let error = vm.inlineError {
                Text(error)
                    .font(.system(size: 13))
                    .kerning(-0.1)
                    .foregroundColor(.Nexus.destructive)
                    .multilineTextAlignment(.center)
            }

            Button("Change email address") {
                withAnimation { vm.changeEmail() }
                otpText = ""
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.Nexus.accent)
        }
        .padding(EdgeInsets(top: 26, leading: 18, bottom: 22, trailing: 18))
        .background(Color.Nexus.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.Nexus.border, lineWidth: NexusBorder.base)
        )
        .animation(.easeInOut(duration: 0.2), value: vm.inlineError)
    }

    private var codeField: some View {
        CodeTextField(text: $otpText) { digits in
            vm.otpCode = digits
            vm.verifyOTP()
        }
        .disabled(vm.phase == .otpVerifying)
    }

    // MARK: - Disclaimer (stub links — PARKING_LOT.md)

    private var disclaimer: some View {
        Text("By continuing, you agree to Nexus's [Consumer Terms](https://nexus.app/terms) and [Usage Policy](https://nexus.app/usage), and acknowledge their [Privacy Policy](https://nexus.app/privacy).")
            .font(.system(size: 12.5))
            .kerning(-0.1)
            .foregroundColor(.Nexus.faint)
            .tint(.Nexus.muted)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
    }
}

// MARK: - Code entry field
//
// Pill field, centered text, auto-focus, OTP autofill, auto-submit at 6 digits.

private struct CodeTextField: View {
    @Binding var text: String
    let onComplete: (String) -> Void

    @FocusState private var focused: Bool
    @State private var submitted = false

    var body: some View {
        TextField("", text: $text, prompt: Text("Code").foregroundColor(.Nexus.ghost))
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .multilineTextAlignment(.center)
            .font(.system(size: 17))
            .kerning(text.isEmpty ? -0.2 : 6)
            .foregroundColor(.Nexus.ink)
            .focused($focused)
            .frame(height: 52)
            .frame(maxWidth: .infinity)
            .background(Color.Nexus.cardBackground)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.Nexus.border, lineWidth: NexusBorder.base))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { focused = true }
            }
            .onChange(of: text) { _, new in
                let digits = String(new.filter(\.isNumber).prefix(6))
                if digits != new { text = digits }
                if digits.count == 6, !submitted {
                    submitted = true
                    onComplete(digits)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { submitted = false }
                }
            }
    }
}
