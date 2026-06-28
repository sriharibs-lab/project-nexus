import Combine
import SwiftUI
import UIKit

// MARK: - Settings

struct SettingsView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @State private var pendingScreenshot: UIImage?
    @State private var showFeedback = false

    var body: some View {
        NavigationStack {
            ZStack {
                NexusBackground()

                List {
                    Section {
                        Button {
                            captureAndOpenFeedback()
                        } label: {
                            Text("Send Feedback")
                                .foregroundColor(.Nexus.ink)
                        }
                    }

                    #if DEBUG
                    Section("Debug") {
                        NavigationLink("Glass Playground") {
                            GlassPlaygroundView()
                        }
                    }
                    #endif

                    Section {
                        Button("Sign Out", role: .destructive) {
                            authManager.signOut()
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showFeedback) {
                FeedbackView(preloadedScreenshot: pendingScreenshot)
            }
        }
    }

    /// Capture the current screen contents before navigating, so the
    /// screenshot shows the Settings screen (or whatever was visible)
    /// rather than a blank feedback form.
    private func captureAndOpenFeedback() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = scene.windows.first(where: { $0.isKeyWindow }) else {
            showFeedback = true
            return
        }
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        pendingScreenshot = renderer.image { ctx in
            window.layer.render(in: ctx.cgContext)
        }
        showFeedback = true
    }
}

// MARK: - Feedback

struct FeedbackView: View {
    let preloadedScreenshot: UIImage?

    @StateObject private var vm = FeedbackViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var textFieldFocused: Bool

    init(preloadedScreenshot: UIImage? = nil) {
        self.preloadedScreenshot = preloadedScreenshot
    }

    var body: some View {
        ZStack {
            NexusBackground()

            if vm.didSubmit {
                thanksView
            } else {
                formView
            }
        }
        .navigationTitle("Send Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !vm.didSubmit {
                    submitButton
                }
            }
        }
        .onAppear {
            vm.screenshot = preloadedScreenshot
        }
        .onTapGesture {
            textFieldFocused = false
        }
    }

    // MARK: - Form

    private var formView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NexusSpacing.xl) {
                // Category picker
                categorySection

                // Text input
                textSection

                // Screenshot section
                if vm.screenshot != nil {
                    screenshotSection
                }

                // Error
                if let error = vm.error {
                    Text(error)
                        .font(.Nexus.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, NexusSpacing.standard)
                }
            }
            .padding(.top, NexusSpacing.lg)
            .padding(.bottom, NexusSpacing.xxxl)
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.sm) {
            Text("Category")
                .font(.Nexus.labelMedium)
                .foregroundColor(.Nexus.muted)
                .kerning(NexusKerning.normal)
                .padding(.horizontal, NexusSpacing.standard)

            Picker("Category", selection: $vm.category) {
                ForEach(FeedbackViewModel.FeedbackCategory.allCases) { cat in
                    Text(cat.label).tag(cat)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, NexusSpacing.standard)
        }
    }

    private var textSection: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.sm) {
            Text("Your feedback")
                .font(.Nexus.labelMedium)
                .foregroundColor(.Nexus.muted)
                .kerning(NexusKerning.normal)
                .padding(.horizontal, NexusSpacing.standard)

            TextEditor(text: $vm.text)
                .focused($textFieldFocused)
                .font(.Nexus.bodyMedium)
                .foregroundColor(.Nexus.ink)
                .frame(minHeight: 140)
                .padding(NexusSpacing.md)
                .background(Color.Nexus.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: NexusRadius.base))
                .overlay(
                    RoundedRectangle(cornerRadius: NexusRadius.base)
                        .stroke(
                            textFieldFocused ? Color.Nexus.accent : Color.Nexus.border,
                            lineWidth: textFieldFocused ? NexusBorder.medium : NexusBorder.hair
                        )
                )
                .padding(.horizontal, NexusSpacing.standard)
                .overlay(alignment: .topLeading) {
                    if vm.text.isEmpty {
                        Text("Describe what you saw, expected, or wish existed…")
                            .font(.Nexus.bodyMedium)
                            .foregroundColor(.Nexus.ghost)
                            .padding(.horizontal, NexusSpacing.standard + NexusSpacing.md + 4)
                            .padding(.top, NexusSpacing.md + 8)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private var screenshotSection: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.sm) {
            HStack {
                Text("Screenshot")
                    .font(.Nexus.labelMedium)
                    .foregroundColor(.Nexus.muted)
                    .kerning(NexusKerning.normal)
                Spacer()
                Toggle("", isOn: $vm.includeScreenshot)
                    .labelsHidden()
                    .tint(.Nexus.accent)
            }
            .padding(.horizontal, NexusSpacing.standard)

            if vm.includeScreenshot, let img = vm.screenshot {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: NexusRadius.base))
                    .overlay(
                        RoundedRectangle(cornerRadius: NexusRadius.base)
                            .stroke(Color.Nexus.border, lineWidth: NexusBorder.hair)
                    )
                    .padding(.horizontal, NexusSpacing.standard)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .animation(.easeInOut(duration: 0.2), value: vm.includeScreenshot)
            } else {
                HStack {
                    Image(systemName: "photo.slash")
                        .font(.system(size: 15))
                        .foregroundColor(.Nexus.ghost)
                    Text("Screenshot excluded")
                        .font(.Nexus.caption)
                        .foregroundColor(.Nexus.ghost)
                }
                .padding(.horizontal, NexusSpacing.standard)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: vm.includeScreenshot)
            }
        }
    }

    // MARK: - Submit button (toolbar)

    private var submitButton: some View {
        Button {
            textFieldFocused = false
            Task { await vm.submit() }
        } label: {
            if vm.isSubmitting {
                ProgressView()
                    .tint(.Nexus.accent)
            } else {
                Text("Send")
                    .font(.Nexus.labelLarge)
                    .foregroundColor(vm.canSubmit ? .Nexus.accent : .Nexus.ghost)
            }
        }
        .disabled(!vm.canSubmit)
    }

    // MARK: - Thanks

    private var thanksView: some View {
        VStack(spacing: NexusSpacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(.Nexus.accent)

            VStack(spacing: NexusSpacing.sm) {
                Text("Thank you")
                    .font(.Nexus.headingSmall)
                    .foregroundColor(.Nexus.ink)
                    .kerning(NexusKerning.tighter)

                Text("Your feedback helps Nexus improve.")
                    .font(.Nexus.bodyMedium)
                    .foregroundColor(.Nexus.muted)
                    .multilineTextAlignment(.center)
            }

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.Nexus.labelLarge)
                    .foregroundColor(.Nexus.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: NexusSpacing.buttonHeight)
                    .background(Color.Nexus.accent)
                    .clipShape(RoundedRectangle(cornerRadius: NexusRadius.md))
            }
            .padding(.horizontal, NexusSpacing.standard)
            .padding(.top, NexusSpacing.md)
        }
        .padding(NexusSpacing.xl)
    }
}
