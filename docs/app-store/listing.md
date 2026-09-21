# App Store 掲載用の文言(たたき台)

App Store Connect に貼るための下書き。文字数の上限は Apple の規定。数字は貼る前に実機で確認する。
このファイルは公開リポジトリに置くため、個人情報・Team ID は書かない。連絡先は組織用のメールアドレスだけを載せる。

## 共通

| 項目 | 値 |
|---|---|
| アプリ名 | Nuvo: Free Photo Editor(23 文字 / 上限 30) |
| カテゴリ | 写真/ビデオ |
| 価格 | 無料(アプリ内課金なし) |
| プライバシーポリシー URL | 公開後の URL を入れる(下の「公開手順」) |
| サポート URL | https://github.com/IK-Lv7/nuvo/issues |
| 連絡先メール(審査用・ポリシー記載) | hinode.entertainment+nuvo@gmail.com |
| 著作権 | 2026 Hinode Entertainment |
| App Privacy | 「データを収集しない」 |
| 暗号化の使用 | 免除(`ITSAppUsesNonExemptEncryption` = NO を設定済み) |

## 日本語

**サブタイトル**(上限 30)
`全機能無料・透かしなし・通信なし`

**プロモーションテキスト**(上限 170)
`すべての機能が、最初から無料です。サブスクも透かしも広告もありません。写真はスマホの外に出ません。`

**説明文**
```
Nuvo は、ポートレートを「いちばん調子のいい日の自分」に近づける、写真加工アプリです。

■ すべて無料
サブスクなし。買い切りなし。「Pro」なし。透かしなし。回数制限なし。どの機能も、最初の1タップから使えます。

■ 写真は、あなたのもの
・インターネットに接続しません。写真はスマホの外に出ません
・アカウント登録は不要です
・広告も、解析ツールも、トラッカーもありません
・何も収集しません
・書き出した写真から、位置情報を消せます(初期設定でオン)

■ できること
・自然な肌: なめらか、明るさ、血色、くま。質感を残したまま整えます
・ニキビ・シミ: タップで消す、自動で見つける
・顔立ち: 小顔、目、あご、鼻、鼻筋
・メイク: リップ、チーク、アイブロウ、歯のホワイトニング
・集合写真: 複数人が写っているとき、加工する人を選べます(タップ、または指で囲む)
・背景: ぼかす、単色にする。ポートレートモードの写真は奥行き情報も使います
・証明写真: 35×45mm、30×40mm をワンタップで
・構図: トリミング、回転、傾き補正、ズーム
・文字入れ: いろいろな書体
・フィルター18種、フィルムの粒子、光漏れ
・ルック: お気に入りの設定を保存して、たくさんの写真にまとめて適用
・書き出し: JPEG / HEIC / PNG、画質の選択

■ やりすぎない
どの効果にも自然さの上限があるので、最大にしても「のっぺり」しません。長押しで、いつでも元の写真と見比べられます。

※ 証明写真は、日本のパスポート・マイナンバーカードの公開されている規格に沿っています。提出先の要件は、必ずご自身でご確認ください。
```

**キーワード**(上限 100、カンマ区切り・空白なし)
`写真加工,美肌,美顔,証明写真,フィルター,背景ぼかし,無料,透かしなし,オフライン,レタッチ,補正,トリミング`

**このバージョンの新機能**
`はじめてのリリースです。`

## English

**Subtitle**(max 30)
`Free. No watermark. Offline.`

**Promotional text**(max 170)
`Every feature is free from the first tap. No subscription, no watermark, no ads. Your photos never leave your phone.`

**Description**
```
Nuvo is a photo editor that helps portraits look like you on your best day.

FREE. ALL OF IT.
No subscription. No one-time purchase. No "Pro" tier. No watermark. No limits. Every tool is open from your very first tap.

YOUR PHOTOS STAY YOURS
- Nuvo doesn't connect to the internet. Photos never leave your phone.
- No account needed.
- No ads, no analytics, no trackers.
- We collect nothing.
- Remove location data from exported photos (on by default).

WHAT YOU CAN DO
- Natural skin: smooth, brighten, add a healthy glow, fade dark circles — keeping skin texture
- Blemishes: fix with a tap, or find them automatically
- Face: slim the face, enlarge eyes, refine the chin and nose
- Makeup: lipstick, blush, brows, teeth whitening
- Group photos: choose whose face to edit (tap, or draw a circle)
- Background: blur or replace it. Portrait Mode photos use their depth data
- ID photos: 35 x 45 mm and 30 x 40 mm in one tap
- Composition: crop, rotate, straighten, zoom
- Add text in a range of typefaces
- 18 filters, film grain, light leak
- Looks: save your favorite settings and apply them to many photos at once
- Export as JPEG, HEIC, or PNG at the quality you want

MADE TO LOOK LIKE YOU
Every effect has a built-in natural limit, so even the maximum setting doesn't look plastic. Press and hold to compare with your original at any time.

The ID photo layouts follow the published guidelines for Japanese passport and My Number card photos. Always check the requirements of wherever you submit the photo.
```

**Keywords**(max 100)
`photo editor,retouch,beautify,portrait,id photo,filters,blur background,free,no watermark,offline`

**What's New**
`First release.`

## 審査メモ(App Review Information)

```
Nuvo is fully offline and free. It has no account, no login, no in-app purchases, no ads, and no network access, so no demo account is needed.

To test: tap the photo icon and choose any photo that contains a face (Face features need a visible face). Choose a category at the bottom, then a tool, then move the slider. Press and hold the photo to compare with the original. The save button writes to the photo library (add-only permission).

The "Who to edit" tool appears only when the photo has two or more faces.
Camera access is not used. Only the system photo picker is used to read photos.
```

## App Store Connect の回答

| 質問 | 回答 |
|---|---|
| App Privacy | データを収集しない |
| トラッキング | しない(ATT なし) |
| 年齢レーティング | 該当項目はすべて「なし」。ユーザー生成コンテンツ・Web アクセス・課金・ギャンブルなし |
| 輸出コンプライアンス | 標準的な暗号化のみ(または免除)。`ITSAppUsesNonExemptEncryption` = NO |
| 広告識別子(IDFA) | 使用しない |
| 価格 | 無料 |

## 公開手順(プライバシーポリシー URL)

1. GitHub の Settings → Pages で、Source を「Deploy from a branch」、Branch を `main`・フォルダを `/docs` にする。
2. 数分後、`https://ik-lv7.github.io/nuvo/privacy-policy` で開けることを確認する。
3. その URL を、App Store Connect の「プライバシーポリシー URL」に入れる。

## 提出前の確認(要・実機)

- [ ] TestFlight で、機内モードにして、全機能が動く
- [ ] 肌・顔の効果を最大にしても、不自然に見えない(複数人の写真で確認)
- [ ] 48MP の写真を書き出して、落ちない
- [ ] 日本語・英語の両方で、文字が切れない
- [ ] スクリーンショットを撮る(6.9 インチ。日本語・英語)
