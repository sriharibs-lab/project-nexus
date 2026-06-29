import AuthenticationServices
import SwiftUI

// MARK: - Auth screen

struct AuthView: View {
    @StateObject private var vm = AuthViewModel()
    @State private var appeared = false
    @State private var emailText = ""
    @State private var otpText = ""
    @State private var isSignUp = false

    private var isOTPPhase: Bool {
        if case .otpEntry = vm.phase { return true }
        if case .otpVerifying = vm.phase { return true }
        return false
    }

    private var emailExpanded: Bool {
        vm.phase == .emailEntry || vm.phase == .emailSending
    }

    var body: some View {
        ZStack {
            NexusBackground()
            if isOTPPhase {
                otpContent.transition(.opacity)
            } else {
                mainContent.transition(.opacity)
            }
        }
        .animation(.timingCurve(0.2, 0.8, 0.2, 1.0, duration: NexusDuration.slow), value: isOTPPhase)
        .onAppear { withAnimation { appeared = true } }
    }

    // MARK: - Main screen (login + signup share layout)

    private var mainContent: some View {
        VStack(spacing: 0) {
            Spacer()
            logoSection
            Spacer()
            Spacer()
            authStack
            Spacer().frame(height: NexusSpacing.safeBottom + NexusSpacing.xxl)
        }
    }

    private var logoSection: some View {
        VStack(spacing: NexusSpacing.lg) {
            EchoMark(color: Color.Nexus.accent, size: 52)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)
                .animation(.timingCurve(0.2, 0.8, 0.2, 1.0, duration: NexusDuration.slow), value: appeared)

            VStack(spacing: NexusSpacing.sm) {
                Text("Nexus")
                    .font(.Nexus.displayMedium)
                    .foregroundColor(.Nexus.ink)
                    .kerning(NexusKerning.tighter)
                Text("Your AI research companion")
                    .font(.Nexus.bodyMedium)
                    .foregroundColor(.Nexus.muted)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .animation(.timingCurve(0.2, 0.8, 0.2, 1.0, duration: NexusDuration.slow).delay(0.1), value: appeared)
        }
    }

    private var authStack: some View {
        VStack(spacing: NexusSpacing.md) {
            // Screen heading
            Text(isSignUp ? "Create your Nexus account" : "Log in to your Nexus account")
                .font(.Nexus.labelLarge)
                .foregroundColor(.Nexus.ink)
                .kerning(NexusKerning.normal)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Apple sign-in (login only, hidden when email is expanded)
            if !isSignUp && !emailExpanded {
                ZStack {
                    // Invisible but functional — Apple requires the official button to be present
                    SignInWithAppleButton(.signIn) { req in
                        req.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        vm.handleAppleSignIn(result: result)
                    }
                    .frame(height: 52)
                    .opacity(0.011)
                    .disabled(vm.phase == .signingIn)

                    // Visual layer — matches email button exactly
                    AuthOptionRow(appleLabel: "Sign in with Apple", isLoading: vm.phase == .signingIn)
                        .allowsHitTesting(false)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Email section — button or inline form
            emailSection

            // Mode toggle (hidden while email is being entered)
            if !emailExpanded {
                HStack(spacing: 4) {
                    Text(isSignUp ? "Already have an account?" : "New user?")
                        .font(.Nexus.bodySmall)
                        .foregroundColor(.Nexus.muted)
                    Button(isSignUp ? "Log in" : "Sign up") {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.75)) {
                            isSignUp.toggle()
                            if isSignUp {
                                vm.showEmailEntry()
                                emailText = ""
                            } else {
                                vm.cancelEmailEntry()
                                emailText = ""
                            }
                        }
                    }
                    .font(.Nexus.bodySmall)
                    .fontWeight(.medium)
                    .foregroundColor(.Nexus.accent)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .transition(.opacity)
            }

            // Error
            if case .error(let msg) = vm.phase {
                errorBanner(message: msg) { vm.retryFromError() }
            }

            #if DEBUG
            Button("Continue (dev)") { vm.devBypass() }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.Nexus.faint)
                .padding(.top, NexusSpacing.xs)
            #endif
        }
        .padding(.horizontal, NexusSpacing.sideGutter + NexusSpacing.sm)
        .opacity(appeared ? 1 : 0)
        .animation(.timingCurve(0.2, 0.8, 0.2, 1.0, duration: NexusDuration.slow).delay(0.2), value: appeared)
    }

    // Email section: sign up starts with form directly; login has expand button
    @ViewBuilder
    private var emailSection: some View {
        if isSignUp || emailExpanded {
            VStack(spacing: NexusSpacing.sm) {
                NexusTextField(
                    placeholder: "your@email.com",
                    text: $emailText,
                    keyboardType: .emailAddress,
                    submitLabel: .send,
                    autoFocus: true,
                    onSubmit: {
                        vm.email = emailText
                        vm.sendMagicLink()
                    }
                )

                NexusPrimaryButton(
                    title: isSignUp ? "Create account" : "Continue",
                    isLoading: vm.phase == .emailSending
                ) {
                    vm.email = emailText
                    vm.sendMagicLink()
                }

                // Cancel only for login email expand (signup has mode toggle below)
                if !isSignUp {
                    Button("Cancel") {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.75)) {
                            vm.cancelEmailEntry()
                            emailText = ""
                        }
                    }
                    .font(.Nexus.bodySmall)
                    .foregroundColor(.Nexus.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .bottom)),
                removal: .opacity.combined(with: .move(edge: .bottom))
            ))
        } else {
            // Login idle state: "Continue with email" — same style as Apple button
            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.75)) {
                    vm.showEmailEntry()
                    emailText = ""
                }
            } label: {
                AuthOptionRow(sfIcon: "envelope", label: "Continue with email",
                              isLoading: vm.phase == .signingIn)
            }
            .buttonStyle(.plain)
            .disabled(vm.phase == .signingIn)
            .transition(.opacity)
        }
    }

    // MARK: - OTP entry

    private var otpContent: some View {
        VStack(spacing: 0) {
            Spacer()
            logoSection
            Spacer()
            Spacer()
            otpInputStack
            Spacer().frame(height: NexusSpacing.safeBottom + NexusSpacing.xxl)
        }
    }

    private var otpInputStack: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.md) {
            VStack(alignment: .leading, spacing: NexusSpacing.xs) {
                Text("Check your email")
                    .font(.Nexus.labelLarge)
                    .foregroundColor(.Nexus.ink)
                    .kerning(NexusKerning.normal)

                if case .otpEntry(let sentEmail) = vm.phase {
                    Text("We sent a 6-digit code to \(sentEmail)")
                        .font(.Nexus.bodySmall)
                        .foregroundColor(.Nexus.muted)
                } else {
                    Text("Enter the 6-digit code from your email")
                        .font(.Nexus.bodySmall)
                        .foregroundColor(.Nexus.muted)
                }
            }

            NexusTextField(
                placeholder: "000000",
                text: $otpText,
                keyboardType: .numberPad,
                submitLabel: .done,
                autoFocus: true,
                onSubmit: {
                    vm.otpCode = otpText
                    vm.verifyOTP()
                }
            )
            .onChange(of: otpText) { _, new in
                let digits = String(new.filter(\.isNumber).prefix(6))
                if digits != otpText { otpText = digits }
                if digits.count == 6 {
                    vm.otpCode = digits
                    vm.verifyOTP()
                }
            }

            NexusPrimaryButton(
                title: "Verify",
                isLoading: vm.phase == .otpVerifying
            ) {
                vm.otpCode = otpText
                vm.verifyOTP()
            }

            HStack {
                Button("Resend code") { vm.resendOTP() }
                    .font(.Nexus.bodySmall)
                    .foregroundColor(.Nexus.accent)
                Spacer()
                Button("Cancel") {
                    withAnimation {
                        vm.cancelOTPEntry()
                        otpText = ""
                        isSignUp = false
                    }
                }
                .font(.Nexus.bodySmall)
                .foregroundColor(.Nexus.muted)
            }
        }
        .padding(.horizontal, NexusSpacing.sideGutter + NexusSpacing.sm)
    }

    // MARK: - Error banner

    @ViewBuilder
    private func errorBanner(message: String, onDismiss: @escaping () -> Void) -> some View {
        HStack(spacing: NexusSpacing.sm) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.Nexus.destructive)
            Text(message)
                .font(.Nexus.caption)
                .foregroundColor(.Nexus.destructive)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.Nexus.ghost)
            }
        }
        .padding(.horizontal, NexusSpacing.md)
        .padding(.vertical, NexusSpacing.sm)
        .background(Color.Nexus.destructive.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: NexusRadius.xs))
        .overlay(
            RoundedRectangle(cornerRadius: NexusRadius.xs)
                .stroke(Color.Nexus.destructive.opacity(0.15), lineWidth: NexusBorder.hair)
        )
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }
}

// MARK: - AuthOptionRow (Notion-style unified sign-in button)

private struct AuthOptionRow: View {
    enum IconKind {
        case sf(String)
        case appleLogo
    }
    let iconKind: IconKind
    let label: String
    var isLoading: Bool = false
    var isDisabled: Bool = false

    init(sfIcon: String, label: String, isLoading: Bool = false, isDisabled: Bool = false) {
        iconKind = .sf(sfIcon)
        self.label = label
        self.isLoading = isLoading
        self.isDisabled = isDisabled
    }

    init(appleLabel: String, isLoading: Bool = false, isDisabled: Bool = false) {
        iconKind = .appleLogo
        self.label = appleLabel
        self.isLoading = isLoading
        self.isDisabled = isDisabled
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(UIColor.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(UIColor.separator), lineWidth: 0.5)
                )

            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(UIColor.label)))
                    .scaleEffect(0.85)
            } else {
                HStack(spacing: 0) {
                    Group {
                        switch iconKind {
                        case .appleLogo:
                            Image(systemName: "apple.logo")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundColor(Color(UIColor.label))
                        case .sf(let name):
                            Image(systemName: name)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(Color(UIColor.label))
                        }
                    }
                    .frame(width: 52, alignment: .center)

                    Text(label)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(Color(UIColor.label))
                        .frame(maxWidth: .infinity, alignment: .center)

                    Spacer().frame(width: 52)
                }
            }
        }
        .frame(height: 52)
        .opacity(isDisabled ? 0.6 : 1)
    }
}

// MARK: - NexusTextField

private struct NexusTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var submitLabel: SubmitLabel = .done
    var autoFocus: Bool = false
    var onSubmit: (() -> Void)? = nil

    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(keyboardType)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .submitLabel(submitLabel)
            .onSubmit { onSubmit?() }
            .font(.Nexus.bodyMedium)
            .foregroundColor(.Nexus.ink)
            .focused($focused)
            .padding(.horizontal, NexusSpacing.standard)
            .padding(.vertical, NexusSpacing.md)
            .background(Color.Nexus.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: NexusRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NexusRadius.md, style: .continuous)
                    .stroke(
                        focused ? Color.Nexus.accent.opacity(0.5) : Color.Nexus.border,
                        lineWidth: NexusBorder.base
                    )
            )
            .onAppear {
                guard autoFocus else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    focused = true
                }
            }
    }
}

// MARK: - NexusPrimaryButton

private struct NexusPrimaryButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.Nexus.bodyMedium)
                    .foregroundColor(.white)
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.85)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: NexusSpacing.buttonHeight)
            .background(Color.Nexus.ink)
            .clipShape(RoundedRectangle(cornerRadius: NexusRadius.md, style: .continuous))
        }
        .disabled(isLoading)
        .scaleEffect(isPressed ? NexusScale.pressLight : 1)
        .animation(NexusAnimation.press, value: isPressed)
        .onLongPressGesture(minimumDuration: 0, pressing: { isPressed = $0 }, perform: {})
    }
}
