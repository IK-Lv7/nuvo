#!/usr/bin/env python3
"""ローカライズの確認(AGENTS.md 第11章: 日本語・英語の両ロケールで文字が破綻しない)。

- すべての文言に、英語と日本語の両方があり、空ではない。
- 英語と日本語で、書式指定(%lld や %@)の数が一致する。
- コードが参照している文言が、定義されている。列挙型から作られるキー(フィルター名など)も含む。

外部のツールには依存しない。手元でも `python3 scripts/check_localization.py` で実行できる。
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "Sources/Resources/Localizable.xcstrings"
LANGUAGES = ("en", "ja")
PLACEHOLDER = re.compile(r"%(?:\d+\$)?(?:lld|ld|d|@|f|s)")

# 列挙型の各 case から作られる文言: (定義ファイル, 列挙型, キーの接頭辞)
ENUM_KEYS = [
    ("Sources/Core/Rendering/Filters/LUTFilter.swift", "FilterPreset", "filter."),
    ("Sources/Core/PhotoLibrary/ImageWriter.swift", "ExportFormat", "settings.format."),
    ("Sources/Core/Rendering/TextOverlay.swift", "TextStyle", "textStyle."),
    ("Sources/Core/Rendering/TextOverlay.swift", "TextColor", "textColor."),
    ("Sources/Core/Rendering/CropAspect.swift", "CropAspect", "crop."),
    ("Sources/Core/Rendering/Filters/BackgroundFilter.swift", "BackgroundColor", "background."),
    ("Sources/Core/Rendering/IDPhoto.swift", "IDPhotoSpec", "idPhoto."),
    ("Sources/Core/Rendering/MakeupTint.swift", "LipstickPreset", "lipstick."),
]
# コードの中で、文字列リテラルとして直接書かれる文言の接頭辞
STATIC_PREFIXES = "editor|empty|tool|category|filter|background|idPhoto|crop|textColor|textStyle|settings|lipstick"

errors: list[str] = []


def enum_cases(path: str, name: str) -> list[str]:
    text = (ROOT / path).read_text(encoding="utf-8")
    match = re.search(r"enum\s+" + name + r"\b[^{]*\{(.*?)\n\}", text, re.S)
    if not match:
        errors.append(f"{path}: 列挙型 {name} が見つからない(このスクリプトの対応表を直すこと)")
        return []
    body = re.sub(r"//[^\n]*", "", match.group(1))
    names: list[str] = []
    # 定義の宣言(`case a, b, c`)だけを数える。`switch` の中の `case .a: ...` は、先頭が `.` なので除く。
    for line in re.findall(r"^\s*case\s+([A-Za-z_][A-Za-z0-9_, ]*)$", body, re.M):
        names += [n.strip() for n in line.split(",") if n.strip()]
    return names


def main() -> int:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))["strings"]

    # 1. すべての文言に、両言語があり、書式指定が一致する
    for key, entry in catalog.items():
        localizations = entry.get("localizations", {})
        values: dict[str, str] = {}
        for lang in LANGUAGES:
            value = localizations.get(lang, {}).get("stringUnit", {}).get("value", "")
            if not value.strip():
                errors.append(f"「{key}」に {lang} の文言がない")
            values[lang] = value
        counts = {lang: len(PLACEHOLDER.findall(v)) for lang, v in values.items()}
        if len(set(counts.values())) > 1:
            errors.append(f"「{key}」の書式指定の数が言語で違う: {counts}")
        key_count = len(PLACEHOLDER.findall(key))
        if key_count and any(c != key_count for c in counts.values()):
            errors.append(f"「{key}」のキーと文言で、書式指定の数が違う: キー {key_count} / {counts}")

    # 2. 列挙型から作られる文言が、すべて定義されている
    checked = 0
    for path, enum, prefix in ENUM_KEYS:
        for case in enum_cases(path, enum):
            checked += 1
            if prefix + case not in catalog:
                errors.append(f"「{prefix}{case}」が未定義({enum}.{case} に対応する文言)")

    # 3. ツール・カテゴリの文言(EditorTool.swift の id から作られる)
    tools = (ROOT / "Sources/Features/Editor/EditorTool.swift").read_text(encoding="utf-8")
    for prefix, pattern in [("category.", r'ToolCategory\(id:\s*"(\w+)"'), ("tool.", r'EditorTool\(id:\s*"(\w+)"')]:
        for ident in re.findall(pattern, tools):
            checked += 1
            if prefix + ident not in catalog:
                errors.append(f"「{prefix}{ident}」が未定義(EditorTool.swift の id)")

    # 4. コードに直接書かれた文言が、定義されている(補間つきのキーは、書式指定に置き換えて照合)
    literal = re.compile(r'"((?:' + STATIC_PREFIXES + r')\.[A-Za-z0-9%\\() ]+)"')
    for path in sorted((ROOT / "Sources/Features").rglob("*.swift")):
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if line.strip().startswith("//"):
                continue
            for key in literal.findall(line):
                checked += 1
                normalized = re.sub(r"\\\([^)]*\)", "%lld", key) if "\\(" in key else key
                # 「filter.\(x.rawValue)」のような列挙型からの動的キーは、2. で確認済み
                if re.search(r"\.%lld$", normalized) and normalized.rsplit(".", 1)[0] + "." in {p for _, _, p in ENUM_KEYS} | {"category.", "tool."}:
                    continue
                if normalized not in catalog:
                    errors.append(f"{path.relative_to(ROOT)}:{number}: 「{normalized}」が未定義")

    for message in errors:
        print(f"::error::{message}")
    if errors:
        print(f"\nローカライズ確認: {len(errors)} 件の問題")
        return 1
    print(f"ローカライズ確認: 問題なし(文言 {len(catalog)} 件、参照 {checked} 件を確認、言語: {', '.join(LANGUAGES)})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
