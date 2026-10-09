import Combine
import PhotosUI
import SwiftUI
import UIKit

// MARK: - Settings

// APP BEHAVIOR only (approved IA tree 2026-07-16): Appearance, Data, About,
// Legal, DEBUG developer tools. Identity lives in Account; Feedback is its
// own top-level menu row. Sheet chrome: X-circle + swipe down.

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    /// Recorded preference; the app currently forces Light (dark palette is
    /// undesigned — Dark/System rows are visible but disabled).
    @AppStorage("nx_appearance") private var appearance = "System"
    @State private var cacheBytes: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                NexusBackground().ignoresSafeArea()

                List {
                    Section("App") {
                        appearanceRow
                    }

                    // Offline reading cache pushes a detail where the red
                    // Clear-cache action lives (device review 2026-07-16).
                    Section("Data") {
                        NavigationLink {
                            OfflineCacheDetailView(bytes: $cacheBytes)
                        } label: {
                            SettingsRow(icon: "internaldrive", label: "Offline reading cache") {
                                SettingsValue(cacheSizeLabel)
                            }
                        }
                    }

                    Section("About") {
                        SettingsRow(icon: "info.circle", label: "Version") {
                            SettingsValue(versionLabel)
                        }
                        Button {
                            openURL(URL(string: "https://nexus-api-bwrh.onrender.com/legal/terms")!)
                        } label: {
                            SettingsRow(icon: "doc.text", label: "Terms of Service") {
                                SettingsExternalArrow()
                            }
                        }
                        .tint(.primary)
                        Button {
                            openURL(URL(string: "https://nexus-api-bwrh.onrender.com/legal/privacy")!)
                        } label: {
                            SettingsRow(icon: "hand.raised", label: "Privacy Policy") {
                                SettingsExternalArrow()
                            }
                        }
                        .tint(.primary)
                    }

                    #if DEBUG
                    Section("Developer") {
                        SettingsRow(icon: "sparkle", label: "Build stamp") {
                            SettingsValue(BuildStamp.short)
                        }
                        NavigationLink {
                            GlassPlaygroundView()
                        } label: {
                            SettingsRow(icon: "circle.hexagongrid", label: "Glass Playground")
                        }
                        NavigationLink {
                            SettingsPlaygroundView()
                        } label: {
                            SettingsRow(icon: "slider.horizontal.3", label: "Settings Playground")
                        }
                    }
                    #endif
                }
                .nexusInsetGrouped()
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
        }
    }

    // MARK: - Appearance (native Menu — Light active, Dark/System "soon")

    private var appearanceRow: some View {
        SettingsRow(icon: "circle.lefthalf.filled", label: "Appearance") {
            Menu {
                ForEach(["System", "Light", "Dark"], id: \.self) { option in
                    Button { appearance = option } label: {
                        if appearance == option { Label(option, systemImage: "checkmark") } else { Text(option) }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(appearance)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.secondary)
            }
            // grey (iOS detail value), not the accent-blue a Menu label defaults to
            .tint(Color(uiColor: .secondaryLabel))
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

// MARK: - Offline cache detail (Data → Offline reading cache)
//
// The red Clear-cache action lives HERE, inside the setting (device review
// 2026-07-16), not as a loose row in the Settings list.

private struct OfflineCacheDetailView: View {
    @Binding var bytes: Int
    @State private var clearing = false

    private var sizeLabel: String {
        bytes == 0 ? "Empty" : ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    var body: some View {
        ZStack {
            NexusBackground().ignoresSafeArea()

            List {
                Section {
                    SettingsRow(icon: "internaldrive", label: "Cached articles") {
                        SettingsValue(sizeLabel)
                    }
                } footer: {
                    Text("Nexus keeps saved articles on your device so you can read them offline. Clearing this frees space — articles re-download when you next open them.")
                }

                if bytes > 0 {
                    Section {
                        Button {
                            guard !clearing else { return }
                            clearing = true
                            Task {
                                await OfflineContentCache.shared.clearAll()
                                bytes = await OfflineContentCache.shared.diskUsageBytes()
                                clearing = false
                            }
                        } label: {
                            SettingsRow(icon: "trash",
                                        label: clearing ? "Clearing…" : "Clear cache",
                                        danger: true)
                        }
                        .tint(.primary)
                        .disabled(clearing)
                    }
                }
            }
            .nexusInsetGrouped()
        }
        .navigationTitle("Offline reading")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Feedback

struct FeedbackView: View {
    let preloadedScreenshot: UIImage?

    @StateObject private var vm = FeedbackViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @FocusState private var textFieldFocused: Bool
    @State private var pickerItem: PhotosPickerItem?

    private let maxChars = 2000

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
        .navigationTitle("Send feedback")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                SheetCloseButton { dismiss() }
            }
        }
        .animation(.easeInOut(duration: 0.22), value: vm.includeScreenshot)
        .animation(.easeInOut(duration: 0.22), value: vm.screenshot != nil)
        // Load the picked screenshot into the VM
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    vm.screenshot = img
                }
            }
        }
        // Toggling off clears any attached screenshot
        .onChange(of: vm.includeScreenshot) { _, on in
            if !on { vm.screenshot = nil; pickerItem = nil }
        }
    }

    // MARK: - Screenshot picker (revealed when the toggle is on)

    @ViewBuilder
    private var screenshotPicker: some View {
        if let shot = vm.screenshot {
            HStack(spacing: NexusSpacing.md) {
                Image(uiImage: shot)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.Nexus.border, lineWidth: NexusBorder.hair)
                    )
                Text("Screenshot attached")
                    .font(.system(size: 15))
                    .kerning(-0.2)
                    .foregroundColor(.Nexus.ink)
                Spacer()
                Button {
                    vm.screenshot = nil
                    pickerItem = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.Nexus.ghost)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
        } else {
            PhotosPicker(selection: $pickerItem, matching: .screenshots) {
                HStack(spacing: 9) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.Nexus.accent)
                    Text("Choose a screenshot")
                        .font(.system(size: 15, weight: .medium))
                        .kerning(-0.2)
                        .foregroundColor(.Nexus.accent)
                    Spacer()
                }
                .padding(.vertical, 13)
                .padding(.horizontal, 14)
                .background(Color.Nexus.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.Nexus.accent.opacity(0.3), lineWidth: NexusBorder.base)
                )
            }
        }
    }

    // MARK: - Form (ChatGPT "Report app issue" layout)

    private var formView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("What happened?")
                        .font(.system(size: 17, weight: .semibold))
                        .kerning(-0.3)
                        .foregroundColor(.Nexus.ink)
                        .padding(.bottom, NexusSpacing.md)

                    // grey filled text area with live counter inside
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.Nexus.surface2)

                        if vm.text.isEmpty {
                            Text("Tell us about the issue you encountered")
                                .font(.system(size: 15.5))
                                .kerning(-0.2)
                                .foregroundColor(.Nexus.ghost)
                                .padding(.horizontal, 20)
                                .padding(.top, 22)
                                .allowsHitTesting(false)
                        }

                        TextEditor(text: $vm.text)
                            .focused($textFieldFocused)
                            .font(.system(size: 15.5))
                            .foregroundColor(.Nexus.ink)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 14)
                            .frame(height: 180)
                            .onChange(of: vm.text) { _, new in
                                if new.count > maxChars { vm.text = String(new.prefix(maxChars)) }
                            }

                        Text("\(vm.text.count) / \(maxChars)")
                            .font(.system(size: 13.5))
                            .foregroundColor(.Nexus.faint)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                            .allowsHitTesting(false)
                    }
                    .frame(height: 180)

                    // disclaimer + contact support
                    (
                        Text("Any information you share may be reviewed to help improve Nexus. If you have additional questions, ")
                            .foregroundColor(.Nexus.muted)
                        + Text("contact support")
                            .foregroundColor(.Nexus.accent)
                    )
                    .font(.system(size: 14))
                    .kerning(-0.15)
                    .lineSpacing(2)
                    .padding(.top, NexusSpacing.md)
                    .padding(.horizontal, 2)
                    .onTapGesture { openURL(URL(string: "mailto:srihari.scorp@gmail.com")!) }

                    // screenshot: OFF by default; ON reveals a Photos browse
                    // button (user picks the screenshot they already took)
                    VStack(spacing: 0) {
                        Rectangle().fill(Color.Nexus.hair).frame(height: NexusBorder.hair)
                        toggleRow("Include screenshot in report", subtitle: nil, isOn: $vm.includeScreenshot)
                        Rectangle().fill(Color.Nexus.hair).frame(height: NexusBorder.hair)
                    }
                    .padding(.top, NexusSpacing.lg)

                    if vm.includeScreenshot {
                        screenshotPicker
                            .padding(.top, NexusSpacing.md)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if let error = vm.error {
                        Text(error)
                            .font(.Nexus.caption)
                            .foregroundColor(.Nexus.destructive)
                            .padding(.top, NexusSpacing.md)
                    }
                }
                .padding(.horizontal, NexusSpacing.standard + 2)
                .padding(.top, NexusSpacing.lg)
                .padding(.bottom, NexusSpacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)

            // bottom full-width Send
            sendButton
                .padding(.horizontal, NexusSpacing.standard)
                .padding(.bottom, NexusSpacing.safeBottom + NexusSpacing.sm)
        }
    }

    private func toggleRow(_ label: String, subtitle: String?, isOn: Binding<Bool>) -> some View {
        HStack(spacing: NexusSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 16))
                    .kerning(-0.2)
                    .foregroundColor(.Nexus.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .kerning(-0.15)
                        .foregroundColor(.Nexus.faint)
                }
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.Nexus.accent)
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 2)
    }

    private var sendButton: some View {
        Button {
            textFieldFocused = false
            Task { await vm.submit() }
        } label: {
            ZStack {
                if vm.isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    Text("Send")
                        .font(.system(size: 16, weight: .semibold))
                        .kerning(-0.2)
                        .foregroundColor(vm.canSubmit ? .white : .Nexus.ghost)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(vm.canSubmit ? Color.Nexus.ink : Color.Nexus.surface2)
            .clipShape(Capsule())
        }
        .buttonStyle(PressableCardStyle())
        .disabled(!vm.canSubmit)
        .animation(NexusAnimation.element, value: vm.canSubmit)
    }

    // MARK: - Thanks

    private var thanksView: some View {
        VStack(spacing: NexusSpacing.lg) {
            ZStack {
                Circle().fill(Color.Nexus.bloom).frame(width: 62, height: 62)
                Image(systemName: "checkmark")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.Nexus.accent)
            }

            VStack(spacing: NexusSpacing.sm) {
                Text("Thank you")
                    .font(.system(size: 18, weight: .bold))
                    .kerning(-0.4)
                    .foregroundColor(.Nexus.ink)
                Text("We read every single one.")
                    .font(.Nexus.bodyMedium)
                    .foregroundColor(.Nexus.muted)
                    .multilineTextAlignment(.center)
            }

            Button { dismiss() } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.Nexus.onInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.Nexus.ink)
                    .clipShape(Capsule())
            }
            .buttonStyle(PressableCardStyle())
            .padding(.horizontal, NexusSpacing.standard)
            .padding(.top, NexusSpacing.md)
        }
        .padding(NexusSpacing.xl)
    }
}
