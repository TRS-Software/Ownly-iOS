// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Ownly",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Ownly", targets: ["Ownly"])
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0"),
        .package(url: "https://github.com/RevenueCat/purchases-ios-spm.git", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "Ownly",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "RevenueCat", package: "purchases-ios-spm"),
            ],
            path: "Ownly"
        ),
        .testTarget(
            name: "OwnlyTests",
            dependencies: ["Ownly"],
            path: "OwnlyTests"
        ),
    ]
)
