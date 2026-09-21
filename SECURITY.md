# Security Policy / セキュリティポリシー

English · [日本語](#日本語)

## Reporting a vulnerability

Please **do not open a public issue** for a security or privacy problem.
Report it privately through GitHub: **Security → Report a vulnerability** on this repository
(private vulnerability reporting).

Please include what you found, how to reproduce it, and what you think the impact is.
Please do not attach personal photos.

This is a small project maintained by one person, so I can't promise a response time,
but I will read every report and do my best to fix real problems quickly.

## What counts

Nuvo is designed to work entirely on your device, with no network access, no accounts,
and no data collection. The most valuable reports are anything that would break those promises:

- code that sends photos or personal data off the device, or could be made to;
- a change that adds tracking, analytics, or a third-party dependency;
- exported photos that leak information the user asked to remove (for example, location);
- secrets or credentials committed to the repository.

## 脆弱性の報告

セキュリティやプライバシーに関する問題は、**公開の Issue に書かないでください**。
このリポジトリの **Security → Report a vulnerability**(非公開の脆弱性報告)から、GitHub 上で
非公開に報告してください。

見つけた内容、再現の手順、影響の見立てを書いてください。個人の写真は添付しないでください。

1人で運営している小さなプロジェクトのため、返信の期限はお約束できませんが、すべての報告に目を通し、
実際の問題は、できるだけ早く直します。

## 対象となるもの

Nuvo は、通信・アカウント・データ収集なしで、すべて端末の中で動くように作られています。
とくに価値が高いのは、この約束を崩すものです。

- 写真や個人情報を端末の外へ送る(または、送らせられる)コード
- トラッキング、解析、外部ライブラリの追加につながる変更
- 消すよう指定した情報(たとえば位置情報)が、書き出した写真に残るもの
- リポジトリに含まれてしまった、秘密情報や認証情報
