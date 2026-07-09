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
    @State private var otpText = ""
    @State private var emailFocused = false

    private var isCodePhase: Bool {
        if case .otpEntry = vm.phase { return true }
        if case .otpVerifying = vm.phase { return true }
        return false
    }

    var body: some View {
        ZStack {
            // Background is the tap-outside-to-dismiss catcher. Controls sit
            // above it and receive their own taps — no simultaneous gestures.
            Color.Nexus.surface3
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { hideKeyboard() }
            if isCodePhase {
                codeScreen.transition(.opacity)
            } else {
                landingScreen.transition(.opacity)
            }
        }
        .animation(.timingCurve(0.2, 0.8, 0.2, 1.0, duration: NexusDuration.slow), value: isCodePhase)
    }

    // MARK: - Landing
    //
    // Two independent layers:
    //  • Hero — dead-center of the screen (vertically + horizontally), pinned:
    //    it ignores the keyboard so focusing the email field never reflows it.
    //  • Auth stack — bottom-anchored; the ONLY layer that keyboard-avoids,
    //    so the email field rises above the keyboard.

    private var landingScreen: some View {
        ZStack {
            // Hero — mark → "Nexus" → tagline; both text rows same font/size/weight.
            // Dead-center when idle; glides to the top (slightly smaller) while
            // the email field is focused, staying visible above the risen stack.
            VStack(spacing: 0) {
                EchoMark(color: Color.Nexus.accent, size: 64)
                Text("Nexus")
                    .font(.system(size: 27, weight: .semibold))
                    .kerning(-0.6)
                    .foregroundColor(.Nexus.ink)
                    .padding(.top, 26)
                Text("Your AI research companion.")
                    .font(.system(size: 27, weight: .semibold))
                    .kerning(-0.6)
                    .foregroundColor(.Nexus.faint)
                    .padding(.top, 10)
            }
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.8)
            .lineLimit(1)
            .padding(.horizontal, 20)
            .scaleEffect(emailFocused ? 0.82 : 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: emailFocused ? .top : .center)
            .padding(.top, emailFocused ? 24 : 0)
            .animation(.timingCurve(0.2, 0.8, 0.2, 1.0, duration: 0.32), value: emailFocused)
            .allowsHitTesting(false)
            .ignoresSafeArea(.keyboard, edges: .bottom)

            // Auth stack — bottom-anchored, keyboard-avoiding
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 12) {
                    appleButton
                    EmailBox(
                        sending: vm.phase == .emailSending,
                        onFocusChange: { emailFocused = $0 },
                        onSubmit: { address in
                            vm.email = address
                            vm.sendMagicLink()
                        }
                    )

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
        }
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
    }

    private var codeField: some View {
        OTPField(
            text: $otpText,
            isEnabled: vm.phase != .otpVerifying,
            onComplete: { digits in
                vm.otpCode = digits
                vm.verifyOTP()
            }
        )
        .frame(height: 52)
        .frame(maxWidth: .infinity)
        .background(Color.Nexus.cardBackground)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.Nexus.border, lineWidth: NexusBorder.base))
    }

    // Background-tap keyboard dismissal. A plain gesture on the background
    // layer only — NOT a simultaneousGesture over the whole screen (that
    // pattern stole taps from the text fields and froze focus; see 1F-004).
    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }

    // MARK: - Disclaimer (stub links — PARKING_LOT.md)

    private var disclaimer: some View {
        Text(disclaimerText)
            .font(.system(size: 12.5))
            .kerning(-0.1)
            .foregroundColor(.Nexus.faint)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
    }

    private var disclaimerText: AttributedString {
        var string = AttributedString(
            "By continuing, you agree to Nexus's Terms and Conditions and acknowledge the Privacy Policy."
        )
        for (phrase, url) in [
            ("Terms and Conditions", "https://nexus.app/terms"),
            ("Privacy Policy", "https://nexus.app/privacy"),
        ] {
            if let range = string.range(of: phrase) {
                string[range].link = URL(string: url)
                string[range].underlineStyle = .single
                string[range].foregroundColor = .Nexus.muted
            }
        }
        return string
    }
}

// MARK: - Email box (isolated subview)
//
// A field, not a button. Send circle appears on a valid address; becomes a
// spinner while the code email is prepared. Text is LOCAL @State so each
// keystroke re-renders only this small view — not the whole auth screen
// (whole-screen re-render per keystroke caused visible typing lag).

private struct EmailBox: View {
    let sending: Bool
    let onFocusChange: (Bool) -> Void
    let onSubmit: (String) -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    private var valid: Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "@", maxSplits: 1)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        let domain = String(parts[1])
        return domain.contains(".") && domain.count > 3 && !domain.hasSuffix(".")
    }

    var body: some View {
        HStack(spacing: 6) {
            TextField(
                "",
                text: $text,
                prompt: Text("Continue with email")
                    .font(.system(size: 16.5))
                    .foregroundColor(.Nexus.ghost)
            )
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.send)
            .focused($focused)
            .onSubmit { submit() }
            .font(.system(size: 16.5))
            .foregroundColor(.Nexus.ink)
            .multilineTextAlignment(text.isEmpty ? .center : .leading)
            .disabled(sending)
            .padding(.leading, 22)

            if valid || sending {
                Button(action: submit) {
                    ZStack {
                        Circle().fill(Color.Nexus.ink).frame(width: 44, height: 44)
                        if sending {
                            // Custom arc spinner — system ProgressView renders a
                            // static grey glyph for its first moments, which read
                            // as a frozen button.
                            ArcSpinner()
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
        .onChange(of: focused) { _, isFocused in
            onFocusChange(isFocused)
        }
    }

    private func submit() {
        guard valid, !sending else { return }
        onSubmit(text)
    }
}

// MARK: - Arc spinner
//
// Deterministic replacement for ProgressView, which renders as a static grey
// glyph while UIActivityIndicatorView spins up.

private struct ArcSpinner: View {
    var color: Color = .white
    var lineWidth: CGFloat = 2
    var size: CGFloat = 18

    @State private var spinning = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.72)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .animation(.linear(duration: 0.75).repeatForever(autoreverses: false), value: spinning)
            .onAppear { spinning = true }
    }
}

// MARK: - Code entry field (UIKit-backed)
//
// UITextField via UIViewRepresentable: SwiftUI's TextField drops QuickType
// one-time-code autofill taps (suggestion tapped → binding never populated).
// UIKit's .oneTimeCode path is reliable. Centered, kerned, auto-focus,
// auto-submit at 6 digits.

private struct OTPField: UIViewRepresentable {
    @Binding var text: String
    var isEnabled: Bool
    let onComplete: (String) -> Void

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.keyboardType = .numberPad
        field.textContentType = .oneTimeCode
        field.textAlignment = .center
        field.font = .systemFont(ofSize: 17)
        field.textColor = UIColor(Color.Nexus.ink)
        field.tintColor = UIColor(Color.Nexus.accent)
        // DO NOT set defaultTextAttributes/typingAttributes here (e.g. for
        // kerning): doing so silently breaks .oneTimeCode AutoFill — tapping
        // the QuickType code suggestion inserts nothing. Known UIKit bug.
        // Kerning is applied post-change in Coordinator.editingChanged.
        field.attributedPlaceholder = NSAttributedString(
            string: "Code",
            attributes: [
                .foregroundColor: UIColor(Color.Nexus.ghost),
                .font: UIFont.systemFont(ofSize: 17),
            ]
        )
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            field.becomeFirstResponder()
        }
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        // NEVER write into the field while it's first responder: SwiftUI's
        // update pass can run between the autofill insertion and the
        // editingChanged callback, and a downward sync of the stale binding
        // would wipe the just-inserted code (the "tapping the suggestion
        // does nothing" bug). Downward sync only when idle (e.g. clearing
        // after "Change email address").
        if !field.isFirstResponder, field.text != text {
            field.text = text
        }
        field.isEnabled = isEnabled
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    // Supabase is configured to send 8-digit codes for this project
    // (dashboard → Auth → Email → OTP length). Update if that changes.
    private static let otpLength = 8

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: OTPField
        private var submitted = false

        init(parent: OTPField) { self.parent = parent }

        // Auto-submit ONLY at the exact expected length — a timer-based
        // debounce fired between slow keystrokes, submitting partial codes;
        // each failed attempt invalidated the real code server-side.
        @objc func editingChanged(_ field: UITextField) {
            let digits = String((field.text ?? "").filter(\.isNumber).prefix(OTPField.otpLength))

            // Apply kerning AFTER the change lands (programmatic sets don't
            // re-fire editingChanged). Never via defaultTextAttributes — that
            // breaks one-time-code AutoFill insertion entirely.
            field.attributedText = NSAttributedString(
                string: digits,
                attributes: [
                    .kern: 6,
                    .font: UIFont.systemFont(ofSize: 17),
                    .foregroundColor: UIColor(Color.Nexus.ink),
                ]
            )
            parent.text = digits

            if digits.count == OTPField.otpLength, !submitted {
                submitted = true
                parent.onComplete(digits)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    self?.submitted = false
                }
            }
        }
    }
}
