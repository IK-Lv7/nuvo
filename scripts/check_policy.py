#!/usr/bin/env python3
"""AGENTS.md の絶対制約を、コードの側で守らせるチェック。

Nuvo の約束は「通信しない・収集しない・課金しない」。これを人の注意だけに頼らず、CI で自動的に確認する。
外部のツールには依存しない(標準ライブラリだけ)。手元でも `python3 scripts/check_policy.py` で実行できる。

失敗(exit 1)にするもの: 絶対制約への違反。
警告にとどめるもの: 「目安」として書かれているもの(1ファイル 300 行)。
"""
import plistlib
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
errors: list[str] = []
warnings: list[str] = []

# 第2章: 通信・広告・解析・課金・トラッキング
FORBIDDEN_API = re.compile(
    r"\b(URLSession|URLRequest|NWConnection|NWPathMonitor|CFNetwork|WKWebView|SFSafariViewController"
    r"|StoreKit|SKPayment|SKProduct|Product\.products"
    r"|Firebase|Amplitude|Mixpanel|Sentry|AppsFlyer|Adjust|Crashlytics|GoogleMobileAds|AdMob|AppLovin"
    r"|AppTrackingTransparency|ASIdentifierManager|ATTrackingManager)\b")
# 第9章: 本番ビルドにデバッグ出力を残さない
DEBUG_OUTPUT = re.compile(r"(?<![A-Za-z0-9_.])(print|debugPrint|dump|NSLog)\(")
# 第9章: force unwrap の禁止(`!=` と、文字列・コメント内は除く)
FORCE_UNWRAP = re.compile(r"(?<=[A-Za-z0-9_\)\]])!(?!=)|\btry!|\bas!")
# 第3章: 外部依存なし。使ってよいのは Apple 標準のフレームワークと、自作のモジュールだけ。
ALLOWED_IMPORTS = {
    "Foundation", "SwiftUI", "UIKit", "Observation", "Combine", "os",
    "CoreGraphics", "CoreImage", "CoreImage.CIFilterBuiltins", "CoreText", "CoreVideo", "ImageIO",
    "Vision", "Photos", "PhotosUI", "AVFoundation", "Metal", "MetalKit", "Accelerate",
    # AppKit は配布物には入らない。NuvoCore は macOS でも `swift test` できるよう macOS もターゲットにしており
    # (Package.swift)、SF Symbols の取得など、UIKit の代わりに `#if canImport(AppKit)` で使う箇所がある。
    "AppKit",
    "NuvoCore",
}
# 第7章: 必要最小限の権限だけを要求する。フェーズ2(カメラ)を見越してカメラは許可する。
ALLOWED_USAGE_KEYS = {"INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription", "INFOPLIST_KEY_NSCameraUsageDescription"}
CREDENTIAL_FILES = re.compile(r"\.(p8|p12|pfx|mobileprovision|keystore|jks)$|(^|/)\.env(\.|$)|(^|/)AuthKey_")
LINE_LIMIT = 300


def strip_code(line: str) -> str:
    """コメントと文字列リテラルを取り除く(それらの中の語を、違反として数えないため)。"""
    line = re.sub(r'"(?:\\.|[^"\\])*"', '""', line)
    return line.split("//", 1)[0]


def swift_files(directory: str) -> list[Path]:
    return sorted((ROOT / directory).rglob("*.swift"))


def check_sources() -> None:
    for path in swift_files("Sources"):
        rel = path.relative_to(ROOT)
        lines = path.read_text(encoding="utf-8").splitlines()
        if len(lines) > LINE_LIMIT:
            warnings.append(f"{rel}: {len(lines)} 行(目安は {LINE_LIMIT} 行。分割を検討)")
        in_block_comment = False
        for number, raw in enumerate(lines, 1):
            if in_block_comment:
                if "*/" in raw:
                    in_block_comment = False
                continue
            if raw.strip().startswith("/*") and "*/" not in raw:
                in_block_comment = True
                continue
            code = strip_code(raw)
            if (m := FORBIDDEN_API.search(code)):
                errors.append(f"{rel}:{number}: 禁止されている API・SDK `{m.group(1)}`(AGENTS.md 第2章)")
            if (m := DEBUG_OUTPUT.search(code)):
                errors.append(f"{rel}:{number}: デバッグ出力 `{m.group(1)}(`(AGENTS.md 第9章)")
            if FORCE_UNWRAP.search(code):
                errors.append(f"{rel}:{number}: force unwrap(AGENTS.md 第9章)。guard let / if let を使うこと")
            if (m := re.match(r"\s*import\s+(?:struct\s+|class\s+|enum\s+|func\s+)?([A-Za-z0-9_.]+)", raw)):
                module = m.group(1)
                if module not in ALLOWED_IMPORTS:
                    errors.append(
                        f"{rel}:{number}: 許可されていないモジュール `{module}`。"
                        "外部依存の追加は、事前の確認が必要(AGENTS.md 第2章・第3章)")


def check_dependencies() -> None:
    package = (ROOT / "Package.swift").read_text(encoding="utf-8")
    if re.search(r"\.package\s*\(", package):
        errors.append("Package.swift: 外部パッケージへの依存があります(AGENTS.md 第2章: 依存ゼロ)")
    project = (ROOT / "project.yml").read_text(encoding="utf-8")
    in_packages = False
    for line in project.splitlines():
        if re.match(r"^packages:", line):
            in_packages = True
            continue
        if in_packages and re.match(r"^\S", line):
            in_packages = False
        if in_packages and re.search(r"\burl:|\bgithub:", line):
            errors.append("project.yml: 外部パッケージへの依存があります(ローカルの `path:` だけを許可)")


def check_privacy() -> None:
    manifest = ROOT / "Sources/Resources/PrivacyInfo.xcprivacy"
    data = plistlib.loads(manifest.read_bytes())
    if data.get("NSPrivacyTracking") is not False:
        errors.append("PrivacyInfo.xcprivacy: NSPrivacyTracking は false でなければならない")
    if data.get("NSPrivacyCollectedDataTypes") != []:
        errors.append("PrivacyInfo.xcprivacy: 収集するデータを宣言してはならない(NSPrivacyCollectedDataTypes は空)")
    if data.get("NSPrivacyTrackingDomains") != []:
        errors.append("PrivacyInfo.xcprivacy: トラッキング用ドメインを宣言してはならない")

    project = (ROOT / "project.yml").read_text(encoding="utf-8")
    for key in re.findall(r"(INFOPLIST_KEY_NS\w*Usage\w*):", project):
        if key not in ALLOWED_USAGE_KEYS:
            errors.append(f"project.yml: 許可されていない権限 `{key}`(必要最小限のみ。AGENTS.md 第7章)")
    if "NSUserTrackingUsageDescription" in project:
        errors.append("project.yml: ATT(NSUserTrackingUsageDescription)は使わない(AGENTS.md 第2章)")


def check_credentials() -> None:
    tracked = subprocess.run(["git", "ls-files"], cwd=ROOT, capture_output=True, text=True, check=True).stdout.split("\n")
    for name in tracked:
        if name and CREDENTIAL_FILES.search(name) and not name.endswith(".env.example"):
            errors.append(f"{name}: 認証情報らしいファイルが追跡されています(Secrets は .gitignore の対象へ)")


def check_prototype() -> None:
    """UI 試作(prototype/)にも、通信・解析の禁止は適用される(AGENTS.md 第13章)。"""
    pattern = re.compile(r"\b(fetch|XMLHttpRequest|WebSocket|axios|analytics|Sentry|Amplitude|Firebase)\b")
    targets = [ROOT / "prototype/App.tsx", *(ROOT / "prototype/src").rglob("*.ts*")]
    for path in targets:
        if not path.exists():
            continue
        for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            code = re.sub(r"'(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\"", "''", raw).split("//", 1)[0]
            if (m := pattern.search(code)):
                errors.append(f"{path.relative_to(ROOT)}:{number}: 試作でも通信・解析は禁止 `{m.group(1)}`(AGENTS.md 第13章)")


def main() -> int:
    check_sources()
    check_dependencies()
    check_privacy()
    check_credentials()
    check_prototype()
    for message in warnings:
        print(f"::warning::{message}")
    for message in errors:
        print(f"::error::{message}")
    checked = len(swift_files("Sources"))
    if errors:
        print(f"\n方針チェック: {len(errors)} 件の違反(Swift {checked} ファイルを確認)")
        return 1
    print(f"方針チェック: 違反なし(Swift {checked} ファイル、警告 {len(warnings)} 件)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
