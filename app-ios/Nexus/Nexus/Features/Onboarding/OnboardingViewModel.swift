import Combine
import Foundation
import SwiftUI

// MARK: - Constants

extension OnboardingViewModel {
    /// Pre-seeded interest topics shown in Screen 2 (below the live trending row).
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

    /// Static fallback shown in the "Trending" row when the backend is unreachable.
    /// Must exactly match the static list in api/app/routers/trending.py.
    static let staticTrendingTopics: [String] = [
        "Artificial Intelligence",
        "Climate & Sustainability",
        "Startups & Venture Capital",
        "Health & Longevity",
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

    @Published var step: Int = 0  // 0=welcome, 1=topics, 2=collection prompt

    /// Topics the user toggled on in Screen 2.
    @Published var selectedTopics: Set<String> = []

    /// Free-text topic the user typed in the custom field.
    @Published var customTopic: String = ""

    // MARK: - Live trending chips (1F-007)

    /// Up to 4 trending topics fetched from the backend at FRE load time.
    /// Starts nil (loading state) → populated or falls back to static list.
    @Published private(set) var trendingTopics: [String]? = nil

    /// True while the trending fetch is in flight.
    @Published private(set) var isFetchingTrending: Bool = false

    /// True if the displayed trending topics came from the live feed (vs. static fallback).
    @Published private(set) var trendingIsLive: Bool = false

    // MARK: - Init

    init() {
        // Kick off the trending fetch as soon as the onboarding flow starts.
        // It runs in the background — TopicsScreen renders static chips
        // while fetch is in flight, then swaps in live ones when they arrive.
        Task { await fetchTrendingTopics() }
    }

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

    // MARK: - Trending fetch (1F-007)

    /// Fetches trending topics from the backend.
    /// On any failure (network, server, timeout), silently falls back to the static list.
    /// Sets trendingTopics on main actor; never throws.
    func fetchTrendingTopics() async {
        guard !isFetchingTrending else { return }
        isFetchingTrending = true
        defer { isFetchingTrending = false }

        if let response = await APIClient.shared.fetchTrendingTopics(),
           !response.topics.isEmpty {
            trendingTopics = Array(response.topics.prefix(4))
            trendingIsLive = response.source == "trends"
        } else {
            // Backend unreachable or returned empty — use the curated static list.
            trendingTopics = Self.staticTrendingTopics
            trendingIsLive = false
        }
    }

    // MARK: - Dev reset

    static func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: completionKey)
    }
}
