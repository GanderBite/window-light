import Testing
@testable import Application

@Test func ApplicationModuleBuildsLinksAndRuns() {
    #expect(String(reflecting: PlaceholderUntilApplicationHasItsFirstType.self) == "Application.PlaceholderUntilApplicationHasItsFirstType")
}
