import Foundation

enum CreationFormat: String, CaseIterable, Codable, Hashable, Sendable {
    case image
    case slideshow
    case video
}

enum Privacy: String, CaseIterable, Codable, Hashable, Sendable {
    case `private`
    case published
}
