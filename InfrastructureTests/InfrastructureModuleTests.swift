import Testing
@testable import Infrastructure

@Test func InfrastructureModuleBuildsLinksAndRuns() {
    #expect(String(reflecting: PlaceholderUntilInfrastructureHasItsFirstType.self) == "Infrastructure.PlaceholderUntilInfrastructureHasItsFirstType")
}
