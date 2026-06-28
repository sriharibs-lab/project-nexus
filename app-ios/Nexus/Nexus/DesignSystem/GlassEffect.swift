import SwiftUI
import UIKit

/// Wraps UIVisualEffectView directly — guarantees real blur on all iOS
/// versions, bypassing SwiftUI's material layer which can render opaque
/// on light backgrounds when colorScheme is forced.
struct VisualEffectBlur: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemUltraThinMaterial
    var cornerRadius: CGFloat = 0

    func makeUIView(context: Context) -> UIVisualEffectView {
        let v = UIVisualEffectView(effect: UIBlurEffect(style: style))
        v.clipsToBounds = true
        v.layer.cornerRadius = cornerRadius
        v.layer.cornerCurve = .continuous
        return v
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
        uiView.layer.cornerRadius = cornerRadius
    }
}
