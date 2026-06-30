import Foundation

/// Routing target for AI generation. String-backed so the persisted form is
/// name-stable — reordering cases must NOT change on-disk values.
enum EngineChoice: String, CaseIterable, Codable, Hashable, Sendable {
    case onDevice
    case openRouter
    case anthropic
}
