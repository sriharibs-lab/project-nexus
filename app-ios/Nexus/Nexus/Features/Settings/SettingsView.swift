import Combine
import SwiftUI
import UIKit

// MARK: - Settings

// APP BEHAVIOR only (approved IA tree 2026-07-16): Appearance, Data, About,
// Legal, DEBUG developer tools. Identity lives in Account; Feedback is its
// own top-level menu row. Sheet chrome: X-circle + swipe down.

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    /// Recorded preference; the app currently forces Light (dark palette is
    /// undesigned — Dark/System rows are visible but disabled).
    @AppStorage("nx_appearance") private var appearance = "Light"
    @State private var cacheBytes: Int = 0
    @State private var confirmingClearCache = false

    var body: some View {
        NavigationStack {
            ZStack {
                NexusBackground()

                List {
                    Section("Appearance") {
                        appearanceRow("Light", enabled: true)
                        appearanceRow("Dark", enabled: false)
                        appearanceRow("System", enabled: false)
                    }

                    Section("Data") {
                        HStack {
                            Text("Offline reading cache")
                                .foregroundColor(.Nexus.ink)
                            Spacer()
                            Text(cacheSizeLabel)
                                .foregroundColor(.Nexus.muted)
                                .font(.Nexus.bodySmall)
                        }
                        Button("Clear cache", role: .destructive) {
                            confirmingClearCache = true
                        }
                        .disabled(cacheBytes == 0)
                    }

                    Section("About") {
                        HStack {
                            Text("Version").foregroundColor(.Nexus.ink)
                            Spacer()
                            Text(versionLabel)
                                .foregroundColor(.Nexus.muted)
                                .font(.Nexus.bodySmall)
                        }
                        #if DEBUG
                        HStack {
                            Text("Build stamp").foregroundColor(.Nexus.ink)
                            Spacer()
                            Text(BuildStamp.short)
                                .foregroundColor(.Nexus.muted)
                                .font(.system(size: 13, design: .monospaced))
                        }
                        #endif
                    }

                    // Stub pages tracked in PARKING_LOT.md — rows are the
                    // permanent home; destinations go live with the domain.
                    Section("Legal") {
                        Link(destination: URL(string: "https://nexus.app/terms")!) {
                            legalRow("Terms of Service")
                        }
                        Link(destination: URL(string: "https://nexus.app/privacy")!) {
                            legalRow("Privacy Policy")
                        }
                    }

                    #if DEBUG
                    Section("Developer") {
                        NavigationLink("Glass Playground") {
                            GlassPlaygroundView()
                        }
                    }
                    #endif
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    SheetCloseButton { dismiss() }
                }
            }
            .task {
                cacheBytes = await OfflineContentCache.shared.diskUsageBytes()
            }
            .confirmationDialog(
                "Clear offline reading cache?",
                isPresented: $confirmingClearCache,
                titleVisibility: .visible
            ) {
                Button("Clear \(cacheSizeLabel)", role: .destructive) {
                    Task {
                        await OfflineContentCache.shared.clearAll()
                        cacheBytes = await OfflineContentCache.shared.diskUsageBytes()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Saved articles will re-download when you open them.")
            }
        }
    }

    // MARK: - Rows

    private func appearanceRow(_ name: String, enabled: Bool) -> some View {
        Button {
            appearance = name
        } label: {
            HStack {
                Text(name)
                    .foregroundColor(enabled ? .Nexus.ink : .Nexus.ghost)
                Spacer()
                if !enabled {
                    Text("Soon")
                        .font(.Nexus.overline)
                        .foregroundColor(.Nexus.ghost)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.Nexus.surface2)
                        .clipShape(Capsule())
                } else if appearance == name {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.Nexus.accent)
                }
            }
        }
        .disabled(!enabled)
    }

    private func legalRow(_ title: String) -> some View {
        HStack {
            Text(title).foregroundColor(.Nexus.ink)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.Nexus.ghost)
        }
    }

    // MARK: - Helpers

    private var cacheSizeLabel: String {
        cacheBytes == 0
            ? "Empty"
            : ByteCountFormatter.string(fromByteCount: Int64(cacheBytes), countStyle: .file)
    }

    private var versionLabel: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
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
            ToolbarItem(placement: .navigationBarLeading) {
                SheetCloseButton { dismiss() }
            }
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
