# Contributing / コントリビュート

English · [日本語](#日本語)

Thanks for your interest in Nuvo! Please read **[AGENTS.md](AGENTS.md)** first. It is the source of truth
for what Nuvo is and what it must never do.

## The short version

Nuvo is **free, offline, and collects nothing**. A change will not be accepted if it:

- adds network access, ads, analytics, tracking, accounts, purchases, watermarks, or feature limits;
- adds a third-party dependency (ask first — the answer is usually no);
- uploads or shares a photo anywhere on its own.

These rules are checked automatically (`python3 scripts/check_policy.py`).

## Reporting problems and ideas

Use **[New issue](../../issues/new/choose)** and pick the form that fits:
bug report, *result looks unnatural* (very helpful while effect strengths are still being tuned),
feedback, or feature request.

## Before you open a pull request

- `swift test` passes (on a Mac), and the app builds.
- `python3 scripts/check_policy.py` and `python3 scripts/check_localization.py` pass.
- New strings exist in **both English and Japanese** (`Sources/Resources/Localizable.xcstrings`).
- New logic has tests. Coordinate conversions and image-processing math especially.
- Image-processing changes: describe the approach and trade-offs in the PR first.
- Don't attach personal photos to issues or pull requests.

`prototype/` is a throwaway UI mockup, not part of the app. See its README.

## コントリビュート

Nuvo に興味を持っていただき、ありがとうございます。まず **[AGENTS.md](AGENTS.md)** をお読みください。
Nuvo が何であり、何をしてはならないかの、基準になる文書です。

## 要点

Nuvo は **無料・オフライン・何も収集しない** アプリです。次のような変更は受け入れられません。

- 通信、広告、解析、トラッキング、アカウント、課金、透かし、機能の制限を加える
- 外部ライブラリの依存を加える(事前にご相談ください。多くの場合、お断りします)
- 写真を、勝手に、どこかへ送る・共有する

これらは自動で確認されます(`python3 scripts/check_policy.py`)。

## 報告・提案の出し方

**[New issue](../../issues/new/choose)** から、合うフォームを選んでください。
不具合、*仕上がりが不自然*(効果の強さを調整している間は、とても助かります)、感想、機能の提案があります。

## Pull Request を出す前に

- `swift test` が通り(Mac で)、アプリがビルドできる。
- `python3 scripts/check_policy.py` と `python3 scripts/check_localization.py` が通る。
- 新しい文言は、**英語と日本語の両方**を追加する(`Sources/Resources/Localizable.xcstrings`)。
- 新しいロジックには、テストを付ける。とくに、座標変換と、画像処理の計算。
- 画像処理の変更は、先に、方針とトレードオフを PR に書く。
- Issue や PR に、個人の写真を添付しない。

`prototype/` は使い捨ての UI 試作で、アプリの一部ではありません。中の README をご覧ください。
