import SwiftUI

struct MainTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            Tab("Home", systemImage: "house", value: AppRouter.Tab.home) {
                NavigationStack(path: $router.homePath) {
                    HomeTabStub()
                        .navigationDestination(for: AppRouter.Route.self, destination: RouteDestination.init)
                }
            }
            Tab("Create", systemImage: "plus.circle", value: AppRouter.Tab.create) {
                NavigationStack(path: $router.createPath) {
                    CreateTabStub()
                        .navigationDestination(for: AppRouter.Route.self, destination: RouteDestination.init)
                }
            }
            Tab("Library", systemImage: "photo.on.rectangle", value: AppRouter.Tab.library) {
                NavigationStack(path: $router.libraryPath) {
                    LibraryTabStub()
                        .navigationDestination(for: AppRouter.Route.self, destination: RouteDestination.init)
                }
            }
            Tab("Settings", systemImage: "gearshape", value: AppRouter.Tab.settings) {
                NavigationStack(path: $router.settingsPath) {
                    SettingsTabStub()
                        .navigationDestination(for: AppRouter.Route.self, destination: RouteDestination.init)
                }
            }
        }
        .sheet(item: $router.activeSheet) { sheet in
            SheetContent(sheet: sheet)
        }
    }
}

// MARK: - Shared route/sheet resolvers

private struct RouteDestination: View {
    let route: AppRouter.Route
    init(_ route: AppRouter.Route) { self.route = route }

    var body: some View {
        switch route {
        case .artifactDetail(let id):      TabStub("Artifact \(id)")
        case .modelRegistry:               TabStub("Model Registry")
        case .apiKeyEntry(let provider):   TabStub("API Key — \(provider.rawValue)")
        case .slideshowEditor(let id):     TabStub("Slideshow Editor \(id)")
        case .publishDestinations(let id): TabStub("Publish \(id)")
        }
    }
}

private struct SheetContent: View {
    let sheet: AppRouter.Sheet
    var body: some View {
        switch sheet {
        case .modelPicker(let draft): TabStub("Model Picker \(draft)")
        case .cloudConsent:           TabStub("Cloud Consent")
        case .saveActions(let id):    TabStub("Save Actions \(id)")
        }
    }
}

// MARK: - P1 tab stubs

private struct HomeTabStub: View     { var body: some View { TabStub("Home").navigationTitle("Home") } }
private struct CreateTabStub: View   { var body: some View { TabStub("Create").navigationTitle("Create") } }
private struct LibraryTabStub: View  { var body: some View { TabStub("Library").navigationTitle("Library") } }
private struct SettingsTabStub: View { var body: some View { TabStub("Settings").navigationTitle("Settings") } }

private struct TabStub: View {
    let label: String
    init(_ label: String) { self.label = label }
    var body: some View { Text(label) }
}
