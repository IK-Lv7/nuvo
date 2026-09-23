#!/usr/bin/env python3
"""realesr-general-x4v3(Real-ESRGAN の軽量版)を Core ML(.mlpackage)に変換する。

このスクリプトはアプリには同梱しない。macOS の CI ランナー上で一度だけ実行し、
結果の .mlpackage を Sources/Resources/Models/ に置くための、ビルド前処理の道具。
(README・AGENTS.md の「ゼロ依存」はアプリ本体の話で、この変換用スクリプトが
 一時的に Python パッケージを使うことはその対象外。実行環境は CI の使い捨て VM。)

モデルの出所: https://github.com/xinntao/Real-ESRGAN (BSD-3-Clause)
公式チェックポイント: realesr-general-x4v3.pth
アーキテクチャ: SRVGGNetCompact(VGG 風の軽量な超解像ネットワーク)。
    公開されているアーキテクチャの説明(num_feat=64, num_conv=32, act=prelu, upscale=4)
    をもとに、この 1 ファイルで完結するようここで再実装する
    (basicsr/realesrgan の pip パッケージは torchvision の新しいバージョンで壊れやすいため、
     依存を増やさずアーキテクチャだけを写す)。
    もし層構成が一致していなければ load_state_dict で例外になり、ここで気づける。

使い方(CI から呼ぶ想定。手元で試す場合も同じ):
    pip install torch --index-url https://download.pytorch.org/whl/cpu
    pip install coremltools numpy
    python3 scripts/model_conversion/convert_realesrgan.py \
        --checkpoint realesr-general-x4v3.pth \
        --output RealESRGANGeneralX4V3.mlpackage
"""
from __future__ import annotations

import argparse
import sys

import torch
from torch import nn


# --- SRVGGNetCompact ---------------------------------------------------------
# 公式実装(realesrgan/archs/srvgg_arch.py, BSD-3-Clause)の構造をそのまま写したもの。
# 学習は一切行わない。公式チェックポイントの重みをそのまま読み込むためだけに使う。
class SRVGGNetCompact(nn.Module):
    def __init__(self, num_in_ch: int = 3, num_out_ch: int = 3, num_feat: int = 64,
                 num_conv: int = 32, upscale: int = 4) -> None:
        super().__init__()
        self.upscale = upscale

        def activation() -> nn.Module:
            return nn.PReLU(num_parameters=num_feat)

        layers: list[nn.Module] = [nn.Conv2d(num_in_ch, num_feat, 3, 1, 1), activation()]
        for _ in range(num_conv):
            layers += [nn.Conv2d(num_feat, num_feat, 3, 1, 1), activation()]
        layers.append(nn.Conv2d(num_feat, num_out_ch * upscale * upscale, 3, 1, 1))
        self.body = nn.Sequential(*layers)
        self.upsampler = nn.PixelShuffle(upscale)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        out = self.upsampler(self.body(x))
        # 学習時、ネットワークは「最近傍拡大からの差分」を出力するよう作られている。
        base = nn.functional.interpolate(x, scale_factor=self.upscale, mode="nearest")
        return out + base


class ScaledOutputForExport(nn.Module):
    """Core ML への変換専用のラッパー。SRVGGNetCompact 自体は公式実装の構造をそのまま写した
    ものなので変更しないが、その出力(0〜1 前後の値。クランプなし)は、公式の推論コードでは
    モデルの外側で `clamp(0, 1)` してから `* 255` してピクセル値に戻している
    (basicsr/utils/img_util.py の tensor2img 相当)。

    Core ML の `ct.ImageType` 出力は「テンソルの値がそのまま 0〜255 のピクセル値」という前提で、
    入力の `scale`/`bias` のような自動変換は出力側には無い
    (https://apple.github.io/coremltools/docs-guides/source/image-inputs.html の
    "ImageType for Output" 節。scale/bias は入力にしか無いと明記されている)。
    この変換を省くと、0〜1 の値がほぼ真っ黒として書き出されてしまう
    (実際に今回、高画質化の書き出しが真っ黒になる不具合として発覚した)。
    """
    def __init__(self, model: SRVGGNetCompact) -> None:
        super().__init__()
        self.model = model

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.model(x).clamp(0, 1) * 255.0


def load_model(checkpoint_path: str) -> SRVGGNetCompact:
    model = SRVGGNetCompact()
    state = torch.load(checkpoint_path, map_location="cpu")
    # 公式チェックポイントは {"params": state_dict} の形で保存されている。
    state_dict = state.get("params", state) if isinstance(state, dict) else state
    model.load_state_dict(state_dict, strict=True)
    model.eval()
    return model


def convert(checkpoint_path: str, output_path: str, tile_size: int) -> None:
    import coremltools as ct  # CI 上でのみ import する(この関数を呼ばない限り不要)。

    model = load_model(checkpoint_path)
    export_model = ScaledOutputForExport(model).eval()
    example_input = torch.rand(1, 3, tile_size, tile_size)
    traced = torch.jit.trace(export_model, example_input)

    # 入出力を ImageType にして、Swift 側では CVPixelBuffer / CGImage をそのまま渡せるようにする
    # (float のテンソルを手動で正規化する必要がない)。
    # 入力名・出力名は Swift 側の RestorationModelRunner.swift と一致させること。
    mlmodel = ct.convert(
        traced,
        inputs=[ct.ImageType(name="tile", shape=example_input.shape,
                             scale=1 / 255.0, bias=[0, 0, 0])],
        outputs=[ct.ImageType(name="upscaledTile")],
        convert_to="mlprogram",
        compute_precision=ct.precision.FLOAT16,
        minimum_deployment_target=ct.target.iOS17,
    )
    mlmodel.short_description = (
        "realesr-general-x4v3 (SRVGGNetCompact, 4x). "
        "Source: https://github.com/xinntao/Real-ESRGAN (BSD-3-Clause)."
    )
    mlmodel.save(output_path)
    print(f"saved: {output_path}")


def verify(output_path: str, tile_size: int) -> None:
    """変換した .mlpackage が Swift 側(RestorationModel.swift)の想定通りかを確認する。
    Xcode が無くても、この関数の出力(CI のログ)だけで判断できるようにする。
    """
    import coremltools as ct
    import numpy as np
    from PIL import Image

    mlmodel = ct.models.MLModel(output_path)
    spec = mlmodel.get_spec()
    input_names = [i.name for i in spec.description.input]
    output_names = [o.name for o in spec.description.output]
    print(f"入力: {input_names}")
    print(f"出力: {output_names}")
    assert input_names == ["tile"], f"入力名が 'tile' ではありません: {input_names}"
    assert output_names == ["upscaledTile"], f"出力名が 'upscaledTile' ではありません: {output_names}"

    # 実際に 1 タイル分の画像を推論させ、大きさが 4 倍になっているかを確認する。
    # 色にはっきり差のある柄にする(単色だと、出力が真っ黒でも「入力の色をぼかしただけ」に
    # 見えかねないため。明るい色と暗い色の両方を含めることで、下のピクセル値チェックが効く)。
    dummy = Image.new("RGB", (tile_size, tile_size), color=(40, 60, 80))
    for x in range(0, tile_size, 8):
        for y in range(0, tile_size, 8):
            dummy.paste((220, 200, 180), (x, y, min(x + 4, tile_size), min(y + 4, tile_size)))
    result = mlmodel.predict({"tile": dummy})
    out = result["upscaledTile"]
    print(f"入力サイズ: {dummy.size} → 出力サイズ: {out.size}")
    expected = tile_size * 4
    assert out.size == (expected, expected), f"出力サイズが想定(4倍)と違います: {out.size}"

    # 出力のピクセル値チェック。Core ML の ImageType 出力は「テンソルの値がそのまま
    # 0〜255のピクセル値」という前提で、モデル側で 0〜1 のまま返すと(自動で255倍されず)
    # ほぼ真っ黒な画像になってしまう。実際にこのバグで高画質化の書き出しが真っ黒になったため、
    # 二度と黙って壊れないよう、平均的な明るさを機械的に確認する。
    arr = np.array(out.convert("RGB"))
    mean_value = arr.mean()
    print(f"出力ピクセル値の平均: {mean_value:.1f}(0〜255)")
    assert mean_value > 20, (
        f"出力がほぼ真っ黒です(平均 {mean_value:.1f})。"
        "モデル出力のスケーリング(clamp(0,1) * 255 など)を確認してください。"
    )
    print("検証OK: RestorationModel.swift の想定(入力名 tile・出力名 upscaledTile・4倍・"
          "0〜255レンジの出力)と一致しています。")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkpoint", required=True, help="realesr-general-x4v3.pth へのパス")
    parser.add_argument("--output", required=True, help="出力先の .mlpackage パス")
    # 128: 実機(Neural Engine)での実績が確認できているタイルサイズ。詳細は README 参照。
    parser.add_argument("--tile-size", type=int, default=128,
                        help="変換時に固定する入力タイルの一辺(px)。Swift 側のタイル分割と合わせる")
    args = parser.parse_args()
    convert(args.checkpoint, args.output, args.tile_size)
    verify(args.output, args.tile_size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
