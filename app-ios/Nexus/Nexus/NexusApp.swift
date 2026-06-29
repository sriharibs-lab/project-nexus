//
//  NexusApp.swift
//  Nexus
//
//  Created by Srihari Srinivasa on 6/13/26.
//

import AuthenticationServices
import Combine
import SwiftUI

@main
struct NexusApp: App {
    @StateObject private var authManager = AuthManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .preferredColorScheme(.light)
        }
    }
}

/// Root routing: auth state drives the view stack.
/// Not authenticated → AuthPlaceholderView (Sign in with Apple in 1B-002)
/// Authenticated → HomeView (HomeView handles empty state by showing FRE inline)
private struct RootView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        if !authManager.isAuthenticated {
            AuthPlaceholderView()
        } else {
            HomeView()
        }
    }
}

// MARK: - Auth screen

private struct AuthPlaceholderView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var appeared = false
    @State private var appleError: String?
    @State private var isSigningIn = false

    var body: some View {
        ZStack {
            NexusBackground()

            VStack(spacing: 0) {
                Spacer()

                // Brand
                VStack(spacing: NexusSpacing.lg) {
                    EchoMarkAuth()
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 14)
                        .animation(.timingCurve(0.2, 0.8, 0.2, 1.0, duration: 0.48), value: appeared)

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
                    .animation(.timingCurve(0.2, 0.8, 0.2, 1.0, duration: 0.48).delay(0.1), value: appeared)
                }

                Spacer()
                Spacer()

                // Auth buttons
                VStack(spacing: NexusSpacing.md) {
                    if isSigningIn {
                        // Spinner shown while the backend token exchange is in-flight
                        HStack(spacing: NexusSpacing.sm) {
                            ProgressView()
                                .tint(Color.Nexus.accent)
                            Text("Signing in…")
                                .font(.Nexus.bodySmall)
                                .foregroundColor(.Nexus.muted)
                        }
                        .frame(height: NexusSpacing.buttonHeight)
                    } else {
                        // Sign in with Apple
                        SignInWithAppleButton(.signIn) { req in
                            req.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            handleAppleResult(result)
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: NexusSpacing.buttonHeight)
                        .clipShape(RoundedRectangle(cornerRadius: NexusRadius.md, style: .continuous))
                    }

                    // Dev bypass — simulator / local testing only
                    Button("Continue without account  (dev only)") {
                        authManager.setSession(token: "dev", userId: UUID())
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.Nexus.faint)

                    if let err = appleError {
                        Text(err)
                            .font(.Nexus.caption)
                            .foregroundColor(.Nexus.destructive)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, NexusSpacing.sideGutter + NexusSpacing.sm)
                .opacity(appeared ? 1 : 0)
                .animation(.timingCurve(0.2, 0.8, 0.2, 1.0, duration: 0.48).delay(0.2), value: appeared)

                Spacer().frame(height: NexusSpacing.safeBottom + NexusSpacing.xxl)
            }
        }
        .onAppear { appeared = true }
    }

    // MARK: - Apple Sign-In handler

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            guard let tokenData = cred.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8) else {
                appleError = "Apple did not provide an identity token. Please try again."
                return
            }

            let email = cred.email
            let fullName: String? = {
                guard let name = cred.fullName else { return nil }
                return [name.givenName, name.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                    .isEmpty ? nil : [name.givenName, name.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
            }()

            isSigningIn = true
            appleError = nil

            Task {
                do {
                    let response = try await APIClient.shared.signInWithApple(
                        identityToken: identityToken,
                        userId: cred.user,
                        email: email,
                        fullName: fullName
                    )
                    // Exchange succeeded — store the server-issued JWT
                    let nexusUserId = UUID(uuidString: response.user.id) ?? UUID()
                    authManager.setSession(token: response.accessToken, userId: nexusUserId)
                } catch {
                    appleError = "Sign in failed: \(error.localizedDescription). Please try again."
                }
                isSigningIn = false
            }

        case .failure(let err):
            // ASAuthorizationError.canceled (code 1001) is the user dismissing the sheet —
            // don't show an error for that.
            let asErr = err as NSError
            if asErr.domain == ASAuthorizationError.errorDomain,
               asErr.code == ASAuthorizationError.canceled.rawValue {
                return
            }
            appleError = err.localizedDescription
        }
    }
}

// MARK: - Echo mark (auth screen variant)

private struct EchoMarkAuth: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.Nexus.bloom.opacity(0.55))
                .frame(width: 80, height: 80)
            ForEach([0, 1, 2], id: \.self) { i in
                let scale = 1.0 - Double(i) * 0.22
                Circle()
                    .trim(from: 0.15, to: 0.85)
                    .stroke(
                        Color.Nexus.accent.opacity(1.0 - Double(i) * 0.28),
                        style: StrokeStyle(lineWidth: 2.5 - Double(i) * 0.5, lineCap: .round)
                    )
                    .frame(width: 40 * scale, height: 40 * scale)
                    .rotationEffect(.degrees(-90))
            }
            Circle()
                .fill(Color.Nexus.accent)
                .frame(width: 7, height: 7)
        }
    }
}
