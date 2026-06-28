import AuthenticationServices
import SwiftUI

// MARK: - Auth screen

/// The real sign-in screen. Replaces AuthPlaceholderView from NexusApp.swift.
/// Sign in with Apple is the primary action; magic link email is secondary.
/// Auth state is driven via AuthManager.shared (singleton), not via environment object.
struct AuthView: View {
    @StateObject private var vm = AuthViewModel()

    @State private var appeared = false

    var body: some View {
        ZStack {
            NexusBackground()
            content
        }
        .onAppear { withAnimation { appeared = true } }
        // When auth completes, AuthManager.isAuthenticated flips → RootView
        // transitions to HomeView automatically — no manual navigation needed here.
    }

    // MARK: - Content phases

    @ViewBuilder
    private var content: some View {
        switch vm.phase {
        case .idle, .signingIn:
            landingContent
        case .emailEntry, .emailSending:
            emailEntryContent
        case .otpEntry, .otpVerifying:
            otpContent
        case .error:
            landingContent   // error inline in landing; user taps retry
        case .done:
            // Transition handled by AuthManager — show nothing
            Color.clear
        }
    }

    // MARK: - Landing (Apple + email option)

    private var landingContent: some View {
        VStack(spacing: 0) {
            Spacer()

            brandMark

            Spacer()
            Spacer()

            ctaStack

            Spacer().frame(height: NexusSpacing.safeBottom + NexusSpacing.xxl)
        }
        .transition(.opacity)
    }

    private var brandMark: some View {
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
            .animation(
                .timingCurve(0.2, 0.8, 0.2, 1.0, duration: NexusDuration.slow).delay(0.1),
                value: appeared
            )
        }
    }

    private var ctaStack: some View {
        VStack(spacing: NexusSpacing.md) {

            // Primary: Sign in with Apple
            SignInWithAppleButton(.signIn) { req in
                req.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                vm.handleAppleSignIn(result: result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: NexusSpacing.buttonHeight)
            .clipShape(RoundedRectangle(cornerRadius: NexusRadius.md, style: .continuous))
            .disabled(vm.phase == .signingIn)

            // Separator
            HStack(spacing: NexusSpacing.md) {
                Rectangle()
                    .fill(Color.Nexus.border)
                    .frame(height: NexusBorder.hair)
                Text("or")
                    .font(.Nexus.caption)
                    .foregroundColor(.Nexus.ghost)
                Rectangle()
                    .fill(Color.Nexus.border)
                    .frame(height: NexusBorder.hair)
            }

            // Secondary: Sign in with email
            EmailSignInButton(isLoading: vm.phase == .signingIn) {
                withAnimation(.timingCurve(0.2, 0.8, 0.2, 1.0, duration: NexusDuration.slow)) {
                    vm.showEmailEntry()
                }
            }

            // Error message
            if case .error(let msg) = vm.phase {
                errorBanner(message: msg) { vm.retryFromError() }
            }

            // Dev bypass — debug builds only
            #if DEBUG
            Button("Continue without account  (dev only)") {
                vm.devBypass()
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.Nexus.faint)
            .padding(.top, NexusSpacing.xs)
            #endif

        }
        .padding(.horizontal, NexusSpacing.sideGutter + NexusSpacing.sm)
        .opacity(appeared ? 1 : 0)
        .animation(
            .timingCurve(0.2, 0.8, 0.2, 1.0, duration: NexusDuration.slow).delay(0.2),
            value: appeared
        )
    }

    // MARK: - Email entry

    private var emailEntryContent: some View {
        VStack(spacing: 0) {
            Spacer()

            brandMark

            Spacer()
            Spacer()

            emailInputStack

            Spacer().frame(height: NexusSpacing.safeBottom + NexusSpacing.xxl)
        }
        .transition(.opacity)
    }

    private var emailInputStack: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.md) {
            Text("Sign in with email")
                .font(.Nexus.labelLarge)
                .foregroundColor(.Nexus.ink)
                .kerning(NexusKerning.normal)

            // Email field
            NexusTextField(
                placeholder: "your@email.com",
                text: $vm.email,
                keyboardType: .emailAddress,
                submitLabel: .send,
                onSubmit: { vm.sendMagicLink() }
            )

            // Send button
            NexusPrimaryButton(
                title: "Send magic link",
                isLoading: vm.phase == .emailSending
            ) {
                vm.sendMagicLink()
            }

            // Cancel
            Button("Cancel") {
                withAnimation(.timingCurve(0.2, 0.8, 0.2, 1.0, duration: NexusDuration.moderate)) {
                    vm.cancelEmailEntry()
                }
            }
            .font(.Nexus.bodySmall)
            .foregroundColor(.Nexus.muted)
            .frame(maxWidth: .infinity, alignment: .center)

        }
        .padding(.horizontal, NexusSpacing.sideGutter + NexusSpacing.sm)
    }

    // MARK: - OTP entry

    private var otpContent: some View {
        VStack(spacing: 0) {
            Spacer()

            brandMark

            Spacer()
            Spacer()

            otpInputStack

            Spacer().frame(height: NexusSpacing.safeBottom + NexusSpacing.xxl)
        }
        .transition(.opacity)
    }

    private var otpInputStack: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.md) {
            VStack(alignment: .leading, spacing: NexusSpacing.xs) {
                Text("Check your email")
                    .font(.Nexus.labelLarge)
                    .foregroundColor(.Nexus.ink)
                    .kerning(NexusKerning.normal)

                if case .otpEntry(let sentEmail) = vm.phase {
                    Text("Enter the 6-digit code sent to \(sentEmail)")
                        .font(.Nexus.bodySmall)
                        .foregroundColor(.Nexus.muted)
                } else {
                    Text("Enter the 6-digit code from your email")
                        .font(.Nexus.bodySmall)
                        .foregroundColor(.Nexus.muted)
                }
            }

            // OTP code field
            NexusTextField(
                placeholder: "000000",
                text: $vm.otpCode,
                keyboardType: .numberPad,
                submitLabel: .done,
                onSubmit: { vm.verifyOTP() }
            )
            .onChange(of: vm.otpCode) { _, new in
                // Auto-submit when 6 digits entered
                let digits = new.filter(\.isNumber)
                vm.otpCode = String(digits.prefix(6))
                if vm.otpCode.count == 6 { vm.verifyOTP() }
            }

            // Verify button
            NexusPrimaryButton(
                title: "Verify code",
                isLoading: vm.phase == .otpVerifying
            ) {
                vm.verifyOTP()
            }

            // Resend + cancel
            HStack {
                Button("Resend code") { vm.resendOTP() }
                    .font(.Nexus.bodySmall)
                    .foregroundColor(.Nexus.accent)

                Spacer()

                Button("Cancel") {
                    withAnimation {
                        vm.cancelOTPEntry()
                    }
                }
                .font(.Nexus.bodySmall)
                .foregroundColor(.Nexus.muted)
            }

        }
        .padding(.horizontal, NexusSpacing.sideGutter + NexusSpacing.sm)
    }

    // MARK: - Shared helpers

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

// MARK: - EmailSignInButton

/// Secondary "Sign in with email" button — hairline border, no fill.
/// Matches the inline surface pattern from DESIGN_LANGUAGE.md §1.
private struct EmailSignInButton: View {
    let isLoading: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: NexusSpacing.sm) {
                Image(systemName: "envelope")
                    .font(.system(size: 15, weight: .medium))
                Text("Continue with email")
                    .font(.Nexus.bodyMedium)
            }
            .foregroundColor(.Nexus.ink)
            .frame(maxWidth: .infinity)
            .frame(height: NexusSpacing.buttonHeight)
            .background(Color.Nexus.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: NexusRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NexusRadius.md, style: .continuous)
                    .stroke(Color.Nexus.border, lineWidth: NexusBorder.base)
            )
        }
        .disabled(isLoading)
        .scaleEffect(isPressed ? NexusScale.pressLight : 1)
        .animation(NexusAnimation.press, value: isPressed)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - NexusTextField

/// Text field for auth screens — solid fill, hairline border.
private struct NexusTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var submitLabel: SubmitLabel = .done
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(keyboardType)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .submitLabel(submitLabel)
            .onSubmit { onSubmit?() }
            .font(.Nexus.bodyMedium)
            .foregroundColor(.Nexus.ink)
            .padding(.horizontal, NexusSpacing.standard)
            .padding(.vertical, NexusSpacing.md)
            .background(Color.Nexus.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: NexusRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NexusRadius.md, style: .continuous)
                    .stroke(Color.Nexus.border, lineWidth: NexusBorder.base)
            )
    }
}

// MARK: - NexusPrimaryButton

/// Ink-filled primary action button with optional loading spinner.
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
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}
