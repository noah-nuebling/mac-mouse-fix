Mac Mouse Fix **3.0.6** は「戻る」と「進む」機能をより多くのアプリに対応させました。
また、いくつかのバグや問題にも対処しています。

### 「戻る」と「進む」機能の改善

「戻る」と「進む」のマウスボタン割り当てが、**より多くのアプリで動作する**ようになりました。対応アプリには以下が含まれます:

- Visual Studio Code、Cursor、VSCodium、Windsurf、Zed、その他のコードエディタ
- プレビュー、メモ、システム設定、App Store、ミュージックなど、多くの標準Appleアプリ
- Adobe Acrobat
- Zotero
- その他多数!

この実装は、[LinearMouse](https://github.com/linearmouse/linearmouse)の優れた「Universal Back and Forward」機能にインスパイアされています。LinearMouseが対応しているすべてのアプリをサポートしているはずです。\
さらに、システム設定、App Store、Apple メモ、Adobe Acrobatなど、通常は戻る・進むにキーボードショートカットが必要なアプリにも対応しています。Mac Mouse Fixはこれらのアプリを検出し、適切なキーボードショートカットをシミュレートします。

これまで[GitHub Issue](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aclosed%20label%3A%22Universal%20Back%20and%20Forward%22)でリクエストされたすべてのアプリに対応しているはずです!(フィードバックありがとうございます!)\
まだ動作しないアプリを見つけた場合は、[機能リクエスト](http://redirect.macmousefix.com/?target=mmf-feedback-feature-request)でお知らせください。



### 「スクロールが断続的に停止する」バグへの対処

一部のユーザーが、**スムーススクロールがランダムに停止する**[問題](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20state%3Aclosed%20stops%20working%20label%3A%22Scroll%20Stops%20Working%20Intermittently%22)を経験していました。

私自身はこの問題を再現できていませんが、潜在的な修正を実装しました:

ディスプレイ同期の設定に失敗した場合、アプリは複数回リトライするようになりました。\
リトライ後も動作しない場合、アプリは以下を実行します:

- 「Mac Mouse Fix Helper」バックグラウンドプロセスを再起動し、問題が解決する可能性があります
- クラッシュレポートを生成し、バグの診断に役立てます

この問題が解決されることを願っています!もし解決しない場合は、[バグレポート](http://redirect.macmousefix.com/?target=mmf-feedback-bug-report)または[メール](http://redirect.macmousefix.com/?target=mailto-noah)でお知らせください。



### フリースピンスクロールホイールの動作改善

MX Masterマウス(またはフリースピンスクロールホイールを搭載した他のマウス)でスクロールホイールを自由に回転させた場合、Mac Mouse Fixは**スクロールを高速化しなくなりました**。

この「スクロール高速化」機能は通常のスクロールホイールでは便利ですが、フリースピンスクロールホイールでは制御が難しくなることがあります。

**注意:** Mac Mouse Fixは現在、MX Masterを含むほとんどのLogitechマウスと完全には互換性がありません。完全なサポートを追加する予定ですが、おそらく時間がかかります。それまでの間、私が知る限り最良のLogitechサポート付きサードパーティドライバは[SteerMouse](https://plentycom.jp/en/steermouse/)です。





### バグ修正

- Mac Mouse Fixがシステム設定で以前無効化されたキーボードショートカットを再有効化することがある問題を修正
- 「ライセンスを有効化」をクリックした際のクラッシュを修正
- 「ライセンスを有効化」をクリックした直後に「キャンセル」をクリックした際のクラッシュを修正(レポートありがとう、Ali!)
- Macにディスプレイが接続されていない状態でMac Mouse Fixを使用しようとした際のクラッシュを修正
- アプリ内でタブを切り替える際のメモリリークとその他の内部的な問題を修正

### 視覚的な改善

- [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5)で導入された、Aboutタブが時々高すぎる問題を修正
- 「無料期間が終了しました」通知のテキストが中国語で切れなくなりました
- 入力を記録した後の「+」フィールドの影の視覚的な不具合を修正
- 「ライセンスキーを入力」画面でプレースホルダーテキストが中央からずれて表示されることがある稀な不具合を修正
- ダーク/ライトモードを切り替えた後、アプリに表示される一部の記号の色が間違っていた問題を修正

### その他の改善

- タブ切り替えアニメーションなど、一部のアニメーションを若干効率化
- 「ライセンスキーを入力」画面でTouch Barのテキスト補完を無効化
- その他、さまざまな小規模な内部的改善

*Claudeの優れた支援により編集されました。*

---

前回のリリース[3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5)もぜひご覧ください。