// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "WindowLightLayers",
    defaultLocalization: "en",
    platforms: [.macOS("27.0")],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Application", targets: ["Application"]),
        .library(name: "Infrastructure", targets: ["Infrastructure"]),
        .library(name: "Presentation", targets: ["Presentation"]),
        .library(name: "Features", targets: ["Features"])
    ],
    targets: [
        .target(name: "Domain", path: "Domain"),
        .testTarget(name: "DomainTests", dependencies: ["Domain"], path: "DomainTests"),
        .target(name: "Application", dependencies: ["Domain"], path: "Application"),
        .testTarget(name: "ApplicationTests", dependencies: ["Application", "Domain"], path: "ApplicationTests"),
        .target(name: "Infrastructure", dependencies: ["Domain", "Application"], path: "Infrastructure"),
        .testTarget(name: "InfrastructureTests", dependencies: ["Infrastructure", "Application", "Domain"], path: "InfrastructureTests"),
        .target(name: "Presentation", dependencies: ["Domain"], path: "Presentation"),
        .testTarget(name: "PresentationTests", dependencies: ["Presentation"], path: "PresentationTests"),
        .target(name: "Features", dependencies: ["Application", "Domain", "Presentation"], path: "Features"),
        .testTarget(name: "FeaturesTests", dependencies: ["Features", "Application", "Domain"], path: "FeaturesTests")
    ]
)
