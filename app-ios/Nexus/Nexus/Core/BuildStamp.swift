import Foundation

/// A human-readable identifier for the running build, shown in DEBUG UI so
/// device testing never wonders "is this the new build?" again.
/// Uses the compile time of this file — it changes on every rebuild that
/// touches anything, which is exactly the granularity testing needs.
enum BuildStamp {
    /// e.g. "Jul 9 14:52"
    static let short: String = {
        let compiled = "\(#file)" // anchor so the constant isn't optimized oddly
        _ = compiled
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d HH:mm"
        // __DATE__/__TIME__ aren't available in Swift; the executable's
        // modification date is the build time.
        if let url = Bundle.main.executableURL,
           let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let date = attrs[.modificationDate] as? Date {
            return formatter.string(from: date)
        }
        return "unknown"
    }()
}
