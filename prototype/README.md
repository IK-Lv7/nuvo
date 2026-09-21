# Nuvo Dev(UI 試作アプリ)

Nuvo の UI を素早く詰めるための試作。製品ではなく、App Store には出さない。
決まった内容は `Sources/`(SwiftUI)へ写す。位置づけは [AGENTS.md](../AGENTS.md) の第13章を参照。

## 仕組み(JS だけの変更が iPhone に即時反映される)

1. **Development Build** を一度だけ iPhone に入れる。Expo Go の代わりになる専用アプリで、JS バンドルは埋め込まれない。
2. PC で Metro bundler を起動する。
3. iPhone の Development Build が Metro に接続する。JS は Metro から配信される。
4. ソースを保存すると、Metro が差分を検知し、**Fast Refresh** が変更したモジュールだけを WebSocket で送る。再起動もビルドも不要で、多くの場合は状態を保ったまま数百ms〜数秒で画面が更新される。

## 使い方

```bash
cd prototype
npm install
npm run start          # Metro を起動(同じネットワーク上の iPhone 向け)
npm run start:tunnel   # WSL2 など iPhone から直接届かないとき(--tunnel --clear)
```

iPhone の Development Build を開き、Metro の QR コードを読み取る(または同じネットワーク上のサーバーを選ぶ)。

- Fast Refresh が効かないときは、端末を振って開発メニューから Reload を選ぶか、Metro のターミナルで `r` を押す。
- 環境変数(`EXPO_PUBLIC_*`)を変えたときは、`--clear` 付きで Metro を再起動する。`EXPO_PUBLIC_*` は端末側から読める値なので、秘密情報は入れない。

## ネイティブの再ビルドが必要なとき

Development Build を作り直す(`npm run build:dev`)。次のいずれかを変えたとき:

- `app.json` のパーミッション・プラグインの変更
- ネイティブライブラリの追加・更新(`npx expo install ...`)
- Expo SDK / React Native のバージョン変更
- Bundle ID・アイコン・スプラッシュの変更

JS / TypeScript のロジック、コンポーネント、スタイル、文言だけなら再ビルドは不要。

## 初回セットアップ(外部サービスへの操作を含む)

以下は Expo と Apple のアカウントに変更を加える。実行する人が、内容を確認してから行うこと。

1. `npx eas-cli@latest login`(所有者は組織アカウント `hinodeents-team`)
2. `npx eas-cli@latest init` — EAS プロジェクトを作成し、`extra.eas.projectId` を `app.json` に書き込む
3. `npx eas-cli@latest device:create` — iPhone を Apple Developer に登録する(Internal 配布は Ad Hoc 署名のため必須)
4. `npm run build:dev` — Development Build をクラウドで作る。Bundle ID `com.hinodeentertainment.nuvo.dev` の App ID と署名情報が、初回に EAS 経由で作られる
5. ビルド完了後、表示される URL / QR から iPhone にインストールする

Bundle ID は `.dev` 付きで、App Store 版 Nuvo(`com.hinodeentertainment.nuvo`)とは別のアプリとして並んで入る。

## GitHub Actions でビルドする

Actions の「Nuvo Dev iOS development build」を手動実行する([prototype-dev-build.yml](../.github/workflows/prototype-dev-build.yml))。

| 選択肢 | ビルドする場所 | 成果物 |
|---|---|---|
| `cloud`(既定) | EAS のクラウド。ランナーは開始を指示するだけで待たない | EAS が発行する**インストール用 URL / QR**(出力の URL から開く) |
| `local` | この GitHub の macOS ランナー(`eas build --local`) | `.ipa` のアーティファクト(14日保存)。**インストール用 URL は付かない** |

- `local` は EAS のビルド枠を使わずに済むが、`.ipa` を iPhone に入れる手段は別に必要。**Mac が無い環境では、`cloud` を使うほうが現実的。** ネイティブの変更が無い間はどちらも不要。
- 新しい iPhone を登録したときは、`eas device:create` の後に `refresh_devices` を true にして実行する。登録済みの端末だけが、Ad Hoc のビルドを入れられる。新規・更新直後の Apple Developer 会員では、端末の反映に最大24〜72時間かかることがある。

### 必要な設定(GitHub の Secrets / Variables)

| 名前 | 種類 | 用途 |
|---|---|---|
| `EXPO_TOKEN` | Secret | EAS への認証。expo.dev のアクセストークンを、`hinodeents-team` にアクセスできるユーザーで作成する |
| `ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_KEY_P8_BASE64` / `APPLE_TEAM_ID` | Secret | 既に TestFlight 用に登録済みのものを流用。`refresh_devices` のときだけ使う |
| `APPLE_TEAM_TYPE` | Variable(秘密ではない) | `COMPANY_OR_ORGANIZATION` または `INDIVIDUAL`。`refresh_devices` のときだけ使う |

### 前提: 手元で一度、対話式にビルドする

CI は非対話で動くため、次の設定が終わっている必要がある(上の「初回セットアップ」)。

- `eas init` で EAS プロジェクトが作られ、`extra.eas.projectId` が `app.json` に入っている。
- `eas device:create` で iPhone が登録されている。
- `eas build --profile development --platform ios` を対話式で一度成功させ、証明書とプロビジョニングプロファイルが EAS に作られている。

## 守ること

- 認証情報(`.p8`、証明書、トークン)はリポジトリに入れない。
- 通信・解析・課金・アカウントなど、AGENTS.md 第2章の禁止事項は試作にも適用する。
- 本番向けの JS 配信(EAS Update)は使わない。この試作は配布しない。
- 色・余白は `src/theme.ts` を `Sources/App/Theme.swift` と同じ値に保つ。
