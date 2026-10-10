import SwiftUI
import UIKit
import Combine

// MARK: - Poster (AI image + native headline overlay)
//
// The image is generated with no text in it (FLUX via fal.ai); the headline
// and subline are typeset natively over a bottom scrim so the type is always
// crisp and in the brand voice. The same PosterCard is rendered with
// ImageRenderer for "Share as image" — what you share is what you see.

struct PosterCard: View {
    let image: UIImage?
    let headline: String
    let subline: String?
    var collectionName: String? = nil
    var loading = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    placeholder
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            // Bottom scrim — carries the type regardless of what the art does.
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black.opacity(0.18), location: 0.45),
                    .init(color: .black.opacity(0.78), location: 1),
                ],
                startPoint: .top, endPoint: .bottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 8) {
                if let c = collectionName, !c.isEmpty {
                    Text(c.uppercased())
                        .font(.system(size: 10.5, weight: .bold)).kerning(1.4)
                        .foregroundColor(.white.opacity(0.72))
                        .lineLimit(1)
                }
                Text(headline)
                    .font(.system(size: 30, weight: .heavy)).kerning(-0.9)
                    .foregroundColor(.white)
                    .lineSpacing(-2)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
                if let subline, !subline.isEmpty {
                    Text(subline)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.86))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)
                }
                HStack(spacing: 6) {
                    EchoMark(color: .white.opacity(0.9), size: 14)
                    Text("Made with Nexus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 6)
            }
            .padding(22)
            .shadow(color: .black.opacity(0.35), radius: 10, y: 2)
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .background(Color.Nexus.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.black.opacity(0.08), lineWidth: 1))
        .shadow(color: Color(hex: "#5E3F9E").opacity(0.18), radius: 22, y: 10)
        .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
    }

    /// Ember haze while the image streams in (or if it failed).
    private var placeholder: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#3A2E5C"), Color(hex: "#7054AB"), Color(hex: "#B8569C")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Color(hex: "#E8776A").opacity(0.55), .clear], center: .init(x: 0.75, y: 0.3), startRadius: 0, endRadius: 260)
            if loading { ProgressView().tint(.white.opacity(0.8)) }
        }
    }
}

/// Detail-sheet content: the poster, scrollable, with the prompt underneath.
struct PosterView: View {
    let artifact: Artifact
    let image: UIImage?
    let loading: Bool
    var collectionName: String? = nil

    private var content: ArtifactContent { artifact.content ?? ArtifactContent() }

    var body: some View {
        ScrollView {
            VStack(spacing: NexusSpacing.standard) {
                PosterCard(image: image,
                           headline: content.headline ?? artifact.title,
                           subline: content.subline,
                           collectionName: collectionName,
                           loading: loading)
                if let style = content.style {
                    HStack(spacing: 6) {
                        Image(systemName: "paintbrush.pointed.fill").font(.system(size: 11, weight: .semibold))
                        Text(style.prefix(1).uppercased() + style.dropFirst() + " style")
                            .font(.system(size: 12.5, weight: .medium))
                        Spacer()
                        Text("Image generated · headline from your sources")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.Nexus.faint)
                    .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
    }
}

/// Loads a remote image once; shared by the detail sheet and the share renderer.
@MainActor
final class RemoteImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var loading = false

    func load(_ urlString: String?) async {
        guard image == nil, !loading, let s = urlString, let url = URL(string: s) else { return }
        loading = true
        defer { loading = false }
        if let (data, _) = try? await URLSession.shared.data(from: url), let ui = UIImage(data: data) {
            image = ui
        }
    }
}

#if DEBUG
enum PosterPreview {
    @MainActor static func make() -> some View {
        // Procedural stand-in for the generated art (no network in the harness).
        let size = CGSize(width: 900, height: 1200)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            let colors = [UIColor(nexusHex: "#F3E9D7").cgColor, UIColor(nexusHex: "#C9A27A").cgColor, UIColor(nexusHex: "#5B3F97").cgColor]
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.55, 1])!
            c.drawLinearGradient(g, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            c.setFillColor(UIColor(nexusHex: "#E8776A").withAlphaComponent(0.85).cgColor)
            c.fillEllipse(in: CGRect(x: 520, y: 180, width: 300, height: 300))
            c.setFillColor(UIColor(nexusHex: "#130E1A").withAlphaComponent(0.9).cgColor)
            c.fill(CGRect(x: 90, y: 600, width: 420, height: 18))
            c.fill(CGRect(x: 90, y: 660, width: 300, height: 18))
        }
        var content = ArtifactContent()
        content.headline = "Attention is the scarcest resource"
        content.subline = "Why every feed is engineered to keep you scrolling, and what that costs."
        content.style = "editorial"
        let a = Artifact(id: UUID(), collectionId: UUID(), kind: "poster", title: content.headline!, status: "ready",
                         content: content, model: nil, createdAt: "")
        return NavigationStack {
            ZStack {
                Color.Nexus.pageBackground.ignoresSafeArea()
                PosterView(artifact: a, image: img, loading: false, collectionName: "The attention economy")
            }
            .navigationTitle("Poster").navigationBarTitleDisplayMode(.inline)
        }
    }
}
#endif
