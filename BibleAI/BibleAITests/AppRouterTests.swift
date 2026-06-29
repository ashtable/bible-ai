import Testing
import Foundation
@testable import BibleAI

@MainActor
@Suite("Task 3 — AppRouter")
struct AppRouterTests {

    // MARK: - Initial state

    @Test("Fresh router starts on .home with empty paths and no sheet")
    func initialState() {
        let r = AppRouter()
        #expect(r.selectedTab == .home)
        #expect(r.homePath.isEmpty)
        #expect(r.createPath.isEmpty)
        #expect(r.libraryPath.isEmpty)
        #expect(r.settingsPath.isEmpty)
        #expect(r.activeSheet == nil)
    }

    // MARK: - push(_:on:)

    @Test("push appends to the targeted tab's path and leaves the others untouched")
    func pushTargetsCorrectPath() {
        let r = AppRouter()
        let id = UUID()
        r.push(.artifactDetail(creationID: id), on: .library)
        #expect(r.libraryPath == [.artifactDetail(creationID: id)])
        #expect(r.homePath.isEmpty)
        #expect(r.createPath.isEmpty)
        #expect(r.settingsPath.isEmpty)
    }

    @Test("push accumulates in order (acts as a stack)")
    func pushAccumulatesInOrder() {
        let r = AppRouter()
        r.push(.modelRegistry, on: .settings)
        r.push(.apiKeyEntry(provider: .openRouter), on: .settings)
        #expect(r.settingsPath == [.modelRegistry, .apiKeyEntry(provider: .openRouter)])
    }

    @Test("push routes each tab to its own independent path")
    func pushRoutesEachTabIndependently() {
        let r = AppRouter()
        let homeID = UUID(), createID = UUID()
        r.push(.artifactDetail(creationID: homeID), on: .home)
        r.push(.slideshowEditor(creationID: createID), on: .create)
        #expect(r.homePath == [.artifactDetail(creationID: homeID)])
        #expect(r.createPath == [.slideshowEditor(creationID: createID)])
    }

    // MARK: - present(_:)

    @Test("present sets activeSheet to the given sheet")
    func presentSetsSheet() {
        let r = AppRouter()
        let draft = UUID()
        r.present(.modelPicker(jobDraftID: draft))
        #expect(r.activeSheet?.id == AppRouter.Sheet.modelPicker(jobDraftID: draft).id)
    }

    @Test("present replaces an already-active sheet")
    func presentReplacesSheet() {
        let r = AppRouter()
        let creationID = UUID()
        r.present(.cloudConsent)
        r.present(.saveActions(creationID: creationID))
        #expect(r.activeSheet?.id == AppRouter.Sheet.saveActions(creationID: creationID).id)
    }

    // MARK: - resetToRoot(_:)

    @Test("resetToRoot clears only the targeted tab's path")
    func resetToRootClearsTargetedPath() {
        let r = AppRouter()
        r.push(.modelRegistry, on: .home)
        r.push(.modelRegistry, on: .settings)
        r.resetToRoot(.home)
        #expect(r.homePath.isEmpty)
        #expect(r.settingsPath == [.modelRegistry])
    }

    @Test("resetToRoot is a no-op on an already-empty path")
    func resetToRootIdempotentOnEmpty() {
        let r = AppRouter()
        r.resetToRoot(.create)
        #expect(r.createPath.isEmpty)
    }

    @Test("resetToRoot leaves selectedTab and activeSheet alone")
    func resetToRootLeavesTabAndSheet() {
        let r = AppRouter()
        r.selectedTab = .library
        r.present(.cloudConsent)
        r.push(.modelRegistry, on: .library)
        r.resetToRoot(.library)
        #expect(r.libraryPath.isEmpty)
        #expect(r.selectedTab == .library)
        #expect(r.activeSheet?.id == AppRouter.Sheet.cloudConsent.id)
    }

    // MARK: - Sheet.id

    @Test("Sheet.id is equal for the same case and associated value")
    func sheetIDStableForSameValue() {
        let draft = UUID()
        #expect(AppRouter.Sheet.modelPicker(jobDraftID: draft).id
             == AppRouter.Sheet.modelPicker(jobDraftID: draft).id)
    }

    @Test("Sheet.id is distinct across cases (even with the same UUID)")
    func sheetIDDiffersAcrossCases() {
        let id = UUID()
        let ids = Set([
            AppRouter.Sheet.modelPicker(jobDraftID: id).id,
            AppRouter.Sheet.cloudConsent.id,
            AppRouter.Sheet.saveActions(creationID: id).id,
        ])
        #expect(ids.count == 3)
    }

    @Test("Sheet.id differs when the associated value differs")
    func sheetIDDiffersByAssociatedValue() {
        #expect(AppRouter.Sheet.modelPicker(jobDraftID: UUID()).id
             != AppRouter.Sheet.modelPicker(jobDraftID: UUID()).id)
        #expect(AppRouter.Sheet.saveActions(creationID: UUID()).id
             != AppRouter.Sheet.saveActions(creationID: UUID()).id)
    }

    // MARK: - Route / CloudProvider guards

    @Test("Route is Hashable (required by NavigationStack path); CloudProvider embeds cleanly")
    func routeIsHashable() {
        let id = UUID()
        let set: Set<AppRouter.Route> = [
            .artifactDetail(creationID: id),
            .modelRegistry,
            .apiKeyEntry(provider: .anthropic),
        ]
        #expect(set.count == 3)
    }

    @Test("CloudProvider exposes exactly the two cloud providers")
    func cloudProviderCases() {
        #expect(Set(CloudProvider.allCases) == [.openRouter, .anthropic])
    }

    @Test("CloudProvider raw values are the stable persisted strings")
    func cloudProviderRawValues() {
        #expect(CloudProvider.openRouter.rawValue == "openRouter")
        #expect(CloudProvider.anthropic.rawValue == "anthropic")
    }

    @Test("CloudProvider round-trips through Codable for every case")
    func cloudProviderCodableRoundTrip() throws {
        let enc = JSONEncoder(), dec = JSONDecoder()
        for p in CloudProvider.allCases {
            let data = try enc.encode(p)
            #expect(try dec.decode(CloudProvider.self, from: data) == p)
        }
    }
}
