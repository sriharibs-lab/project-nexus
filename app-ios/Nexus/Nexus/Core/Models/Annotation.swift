import Foundation

// MARK: - Annotation
//
// Represents a user-created highlight+annotation on an article's raw_content.
// Stored locally per item (no API sync in v1 — see ARCH_BRIEF.md §1D-004).
//
// Field notes:
//   • startOffset / endOffset — UTF-16 character offsets into raw_content string.
//     UTF-16 chosen because UITextView uses NSRange (UTF-16) internally; converting
//     to/from Swift String.Index at the boundary avoids double-conversion errors.
//   • highlightedText — denormalised snapshot of the selected string at creation time.
//     Allows the store to show annotation cards even if raw_content changes subtly.
//   • color — named token ("plum" | "amber" | "sage") stored as enum, not hex,
//     so the rendering layer can map to the current design token without migration.

struct Annotation: Codable, Identifiable, Equatable {
    let id: UUID
    let itemId: UUID
    let highlightedText: String
    let startOffset: Int   // UTF-16 offset into raw_content
    let endOffset: Int     // UTF-16 offset, exclusive
    let color: HighlightColor
    let createdAt: Date

    // Convenience initialiser — id and createdAt default to now.
    init(
        id: UUID = UUID(),
        itemId: UUID,
        highlightedText: String,
        startOffset: Int,
        endOffset: Int,
        color: HighlightColor,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.itemId = itemId
        self.highlightedText = highlightedText
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.color = color
        self.createdAt = createdAt
    }
}

// MARK: - HighlightColor

enum HighlightColor: String, Codable, CaseIterable {
    case plum   // Color.Nexus.accent.opacity(0.30)
    case amber  // Color(hex: "#F59E0B").opacity(0.30)
    case sage   // Color(hex: "#10B981").opacity(0.30)

    /// Human-readable name shown in the highlight toolbar.
    var displayName: String {
        switch self {
        case .plum:  return "Plum"
        case .amber: return "Amber"
        case .sage:  return "Sage"
        }
    }
}
