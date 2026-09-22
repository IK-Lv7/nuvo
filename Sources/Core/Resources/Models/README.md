# Models

ここには、復元・強化系機能(高画質化など)で使う Core ML モデルを置く。

- 元になるチェックポイント・変換手順: [`scripts/model_conversion/`](../../../../scripts/model_conversion)
- ライセンス表記: [`THIRD_PARTY_NOTICES.md`](../../../../THIRD_PARTY_NOTICES.md)(リポジトリのルート)

`RestorationModel.loadBundled()`(`Sources/Core/Rendering/ML/RestorationModel.swift`)は、
ここに `RealESRGANGeneralX4V3.mlpackage` が無ければ `nil` を返す。呼び出し側は Core Image
だけの処理にフォールバックするので、モデルをまだ置いていない今の状態でも問題なくビルド・動作する。

変換ワークフロー(`.github/workflows/convert-model.yml`)で作った `.mlpackage` を、
中身を確認したうえでこのフォルダにコミットすれば、そのまま使われるようになる。
