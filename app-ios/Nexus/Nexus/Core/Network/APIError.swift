import Foundation

enum APIError: Error, LocalizedError {
    case unauthorized
    case notFound
    case serverError(Int)
    case decodingError(Error)
    case networkError(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .unauthorized:        return "Session expired. Please sign in again."
        case .notFound:            return "Resource not found."
        case .serverError(let c):  return "Server error (\(c))."
        case .decodingError:       return "Failed to read server response."
        case .networkError(let e): return e.localizedDescription
        case .unknown:             return "An unexpected error occurred."
        }
    }
}
