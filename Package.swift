// swift-tools-version: 5.9
import PackageDescription

// 画像処理・座標変換などの UI 非依存ロジック。Mac 上で `swift test` だけで検証できるよう
// アプリ本体(project.yml)とは別の Package にしている。外部依存は追加しない。
let package = Package(
    name: "NuvoCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "NuvoCore", targets: ["NuvoCore"]),
    ],
    targets: [
        .target(
            name: "NuvoCore",
            path: "Sources/Core",
            resources: [
                // 復元・強化系機能(高画質化など)で使う、同梱の Core ML モデル置き場(scripts/model_conversion/README.md 参照)。
                .copy("Resources/Models"),
                // スタンプで使う、同梱の絵文字画像(OpenMoji。THIRD_PARTY_NOTICES.md 参照)。
                .copy("Resources/Stamps"),
            ]
        ),
        .testTarget(
            name: "NuvoCoreTests",
            dependencies: ["NuvoCore"],
            path: "Tests/NuvoCoreTests"
        ),
    ]
)
