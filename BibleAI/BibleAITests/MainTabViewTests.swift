import Testing
import SwiftUI
@testable import BibleAI

@MainActor
@Suite("Task 4 — MainTabView")
struct MainTabViewTests {

    @Test("MainTabView is constructible")
    func mainTabViewConstructs() {
        _ = MainTabView()
    }

    @Test("RootView is constructible with router injected")
    func rootViewConstructs() {
        _ = RootView()
    }

    @Test("Per-tab path isolation under tab switching")
    func perTabPathIsolationUnderTabSwitching() {
        let r = AppRouter()
        let home = UUID(), lib = UUID()
        r.selectedTab = .home
        r.push(.artifactDetail(creationID: home), on: .home)
        r.selectedTab = .library
        r.push(.artifactDetail(creationID: lib), on: .library)
        #expect(r.homePath    == [.artifactDetail(creationID: home)])
        #expect(r.libraryPath == [.artifactDetail(creationID: lib)])
        #expect(r.createPath.isEmpty)
        #expect(r.settingsPath.isEmpty)
        #expect(r.selectedTab == .library)
    }

    @Test("Sheet is global over active tab")
    func sheetIsGlobalOverActiveTab() {
        let r = AppRouter()
        r.selectedTab = .create
        r.push(.modelRegistry, on: .create)
        r.present(.cloudConsent)
        #expect(r.activeSheet?.id == AppRouter.Sheet.cloudConsent.id)
        #expect(r.selectedTab == .create)
        #expect(r.createPath == [.modelRegistry])
    }

    @Test("modelRegistry route is the same value from Create and Settings stacks")
    func modelRegistryReachableFromCreateAndSettings() {
        let r = AppRouter()
        r.push(.modelRegistry, on: .create)
        r.push(.modelRegistry, on: .settings)
        #expect(r.createPath.last == .modelRegistry)
        #expect(r.settingsPath.last == .modelRegistry)
        #expect(r.createPath.last == r.settingsPath.last)
    }
}
