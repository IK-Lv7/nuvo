# サードパーティ通知 / Third-Party Notices

Nuvo 本体は Apple の標準フレームワークのみで作られており、ゼロ依存の方針を保っている
(詳細は [AGENTS.md](AGENTS.md) 第1章・第2章)。唯一の例外が、高画質化・復元系機能で使う
学習済みモデル(重み)で、これは Nuvo が作ったものではない第三者の資産のため、ここに明記する。

`prototype/` の依存については [`prototype/LICENSE`](prototype/LICENSE) と `prototype/README` を参照。

---

## Real-ESRGAN(`realesr-general-x4v3`)

- 用途: 高画質化(`Sources/Core/Rendering/ML/RestorationModel.swift`)
- 変換元: <https://github.com/xinntao/Real-ESRGAN>(公式チェックポイント `realesr-general-x4v3.pth`)
- Nuvo に同梱するのは、これを Core ML 形式(`.mlpackage`)に変換したものであり、重みの値は変更していない
  (変換手順: [`scripts/model_conversion/`](scripts/model_conversion))。
- ライセンス: BSD 3-Clause License

```
BSD 3-Clause License

Copyright (c) 2021, Xintao Wang
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

同じ系列(同じアーキテクチャ・同じライセンス)のモデルを今後追加する場合も、
この節に追記するだけでよい([`scripts/model_conversion/README.md`](scripts/model_conversion/README.md) 参照)。
