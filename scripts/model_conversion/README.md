# モデル変換(高画質化・復元系機能の共通基盤)

`Sources/Resources/Models/` に置く Core ML モデルは、ここにある Python スクリプトで
公式チェックポイントから一度だけ変換して作る。変換自体はアプリのビルドには含まれない
(生成物の `.mlpackage` だけを `Sources/Resources/Models/` にコミットして使う)。

## 今あるもの

| スクリプト | 元モデル | 用途 | ライセンス |
|---|---|---|---|
| `convert_realesrgan.py` | [xinntao/Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN) の `realesr-general-x4v3.pth` | 高画質化(`QualityBoost`)。将来、ノイズ除去単体などの機能もここに追加していく想定 | BSD-3-Clause |

なぜ Real-ESRGAN 系列に揃えているか: `docs/` の議論の通り、実写の劣化(ノイズ・圧縮)を
学習データに含む「復元」系のモデルで、今後似た機能(ノイズ除去、ボケ補正など)を足すときも
同じアーキテクチャ・同じライセンス・同じ変換の枠組みを使い回せるため。

## 実行方法(GitHub Actions)

`.github/workflows/convert-model.yml` を手動実行(workflow_dispatch)すると、
macOS ランナー上でこのスクリプトを動かし、`.mlpackage` を Artifact としてダウンロードできる。
手元に Mac が無くても実行できる。

ダウンロードした `.mlpackage` を確認(Xcode で開いて実際の画像をドラッグして試す、
`MLModel` の入出力名が `tile` / `upscaledTile` になっているか等)したうえで、
`Sources/Resources/Models/` にコミットする。

## 手元で実行する場合

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install torch --index-url https://download.pytorch.org/whl/cpu
pip install coremltools numpy

# 公式リリースからチェックポイントを取得
curl -LO https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesr-general-x4v3.pth

python3 scripts/model_conversion/convert_realesrgan.py \
    --checkpoint realesr-general-x4v3.pth \
    --output RealESRGANGeneralX4V3.mlpackage
```

## 注意

- `convert_realesrgan.py` 内の `SRVGGNetCompact` は、公式実装の構造を読んで書き写したもので、
  学習済みの重みを一切変更しない。層構成が少しでも違えば `load_state_dict` が例外を出すので、
  そこで気づける(黙って壊れることはない)。
- ライセンス表記は `THIRD_PARTY_NOTICES.md`(リポジトリのルート)にまとめている。
  この系列のモデルを追加するときは、そこに追記するだけでよい(ライセンス自体は共通)。
