import Testing
@testable import Domain

@Test func DomainModuleBuildsLinksAndRuns() {
    #expect(String(reflecting: PlaceholderUntilDomainHasItsFirstType.self) == "Domain.PlaceholderUntilDomainHasItsFirstType")
}
