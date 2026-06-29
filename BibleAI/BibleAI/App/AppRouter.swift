import Foundation
import Observation

@MainActor
@Observable
final class AppRouter {

    enum Tab: Hashable { case home, create, library, settings }

    enum Route: Hashable {
        case artifactDetail(creationID: UUID)
        case modelRegistry
        case apiKeyEntry(provider: CloudProvider)
        case slideshowEditor(creationID: UUID)
        case publishDestinations(creationID: UUID)
    }

    enum Sheet: Identifiable {
        case modelPicker(jobDraftID: UUID)
        case cloudConsent
        case saveActions(creationID: UUID)

        var id: String { String(describing: self) }
    }

    var selectedTab: Tab = .home
    var homePath: [Route] = []
    var createPath: [Route] = []
    var libraryPath: [Route] = []
    var settingsPath: [Route] = []
    var activeSheet: Sheet?

    func push(_ route: Route, on tab: Tab) {
        self[keyPath: Self.path(for: tab)].append(route)
    }

    func present(_ sheet: Sheet) {
        activeSheet = sheet
    }

    func resetToRoot(_ tab: Tab) {
        self[keyPath: Self.path(for: tab)].removeAll()
    }

    private static func path(for tab: Tab) -> ReferenceWritableKeyPath<AppRouter, [Route]> {
        switch tab {
        case .home:     \.homePath
        case .create:   \.createPath
        case .library:  \.libraryPath
        case .settings: \.settingsPath
        }
    }
}
