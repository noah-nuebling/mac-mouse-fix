Mac Mouse Fix **3.0.4 Beta 1** はプライバシー、効率性、信頼性を向上させました。\
新しいオフラインライセンスシステムを導入し、重要なバグを修正しました。

### プライバシーと効率性の向上

- インターネット接続を最小限に抑える新しいオフラインライセンス認証システムを導入しました。
- アプリは必要な場合にのみインターネットに接続し、プライバシーを保護しリソース使用を削減します。
- ライセンス認証後は、通常の使用時に完全にオフラインで動作します。

<details>
<summary><b>プライバシーに関する詳細情報</b></summary>
以前のバージョンでは起動時にオンラインでライセンス認証を行っていたため、サードパーティのサーバー（GitHubとGumroad）で接続ログが保存される可能性がありました。新システムでは不要な接続を排除し、初回のライセンス認証後はローカルのライセンスデータが破損した場合にのみインターネットに接続します。
<br><br>
私個人がユーザーの行動を記録することは一切ありませんでしたが、以前のシステムではサードパーティのサーバーがIPアドレスと接続時間を記録する可能性がありました。Gumroadはライセンスキーを記録し、購入時に収集した個人情報と関連付ける可能性もありました。
<br><br>
元のライセンスシステムを構築した際にはこれらの細かいプライバシーの問題を考慮していませんでしたが、現在のMac Mouse Fixは可能な限りプライバシーを重視し、インターネット接続を必要としないものとなっています！
<br><br>
詳しくは<a href=https://gumroad.com/privacy>Gumroadのプライバシーポリシー</a>と私の<a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>GitHubのコメント</a>をご覧ください。

</details>

### バグ修正

- 'Spaces & Mission Control'で'クリック＆ドラッグ'を使用する際にmacOSが時々フリーズする問題を修正しました。
- Mac Mouse Fixで定義した'Mission Control'などの'クリック'アクションを使用する際に、システム設定のキーボードショートカットが時々削除される問題を修正しました。
- アプリを購入済みのユーザーに対して、アプリが動作を停止し'無料期間が終了しました'という通知を表示する[バグ](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22)を修正しました。
    - このバグを経験された方には心からお詫び申し上げます。[こちら](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund)から返金を申請することができます。

### 技術的な改善

- よりクリーンなデータモデリングと人間が読みやすい設定ファイルを可能にする新しい'MFDataClass'システムを実装しました。
- Gumroad以外の決済プラットフォームのサポートを追加。将来的にローカライズされた決済や、異なる国での販売が可能になるかもしれません！

### macOS 10.14 Mojaveの（非公式）サポート終了

Mac Mouse Fix 3は公式にmacOS 11 Big Sur以降をサポートしています。ただし、グラフィックの問題などの不具合を許容できるユーザーは、Mac Mouse Fix 3.0.3以前のバージョンをmacOS 10.14.4 Mojaveで使用することができました。

Mac Mouse Fix 3.0.4ではそのサポートを終了し、**macOS 10.15 Catalina以降が必要**となります。\
ご不便をおかけして申し訳ありません。この変更により、最新のSwift機能を使用して改善されたライセンスシステムを実装することができました。Mojaveユーザーは引き続きMac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3)または[Mac Mouse Fix 2の最新バージョン](https://redirect.macmousefix.com/?target=mmf2-latest)を使用することができます。これが皆様にとって良い解決策となることを願っています。

*Claudeの優れたアシストにより編集されました。*

---

前回のリリース[**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3)もご確認ください。