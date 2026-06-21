import Combine
import Foundation

// MARK: - Constants

extension OnboardingViewModel {
    /// Pre-seeded interest topics shown in Screen 2.
    static let suggestedTopics: [String] = [
        "Artificial Intelligence",
        "Climate & Sustainability",
        "Startups & Venture Capital",
        "Health & Longevity",
        "Design & UX",
        "Science & Research",
        "Global Politics",
        "Personal Finance",
        "Philosophy & Ethics",
        "Web3 & Crypto",
        "Space Exploration",
        "Food & Culture",
    ]
}

// MARK: - ViewModel

@MainActor
final class OnboardingViewModel: ObservableObject {

    // MARK: - Persistence key

    private static let completionKey = "nexus_has_completed_onboarding"

    static var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: completionKey)
    }

    // MARK: - Published state

    @Published private(set) var step: Int = 0  // 0=welcome, 1=topics, 2=collection prompt

    /// Topics the user toggled on in Screen 2.
    @Published var selectedTopics: Set<String> = []

    /// Free-text topic the user typed in the custom field.
    @Published var customTopic: String = ""

    // MARK: - Computed

    /// All topics the user cares about (selected chips + any custom text).
    var finalTopics: [String] {
        var result = Array(selectedTopics).sorted()
        let trimmed = customTopic.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, !result.contains(trimmed) {
            result.append(trimmed)
        }
        return result
    }

    var canProceedFromTopics: Bool {
        !selectedTopics.isEmpty || !customTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Navigation

    func advance() {
        guard step < 2 else { return }
        withAnimation(NexusAnimation.pageForward) {
            step += 1
        }
    }

    func complete() {
        UserDefaults.standard.set(true, forKey: Self.completionKey)
    }

    // MARK: - Topic selection

    func toggleTopic(_ topic: String) {
        if selectedTopics.contains(topic) {
            selectedTopics.remove(topic)
        } else {
            selectedTopics.insert(topic)
        }
    }

    // MARK: - Dev reset

    static func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: completionKey)
    }
}
