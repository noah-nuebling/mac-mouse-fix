### Ventura 対応！
Mac Mouse Fix は macOS 13 Ventura を完全にサポートするようになりました。
GitHub Issue [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297) で Ventura サポートに協力してくれた [@chamburr](https://github.com/chamburr) に特別な感謝を。

### 古い macOS バージョンのサポート終了

残念ながら、macOS 13 Ventura で開発する場合、Apple は macOS 10.13 **High Sierra 以降**向けの開発しか許可していません。

そのため、**最低対応バージョン**が 10.11 El Capitan から 10.13 High Sierra に引き上げられました。

申し訳ありませんが、気分転換に次のセクションでかわいいてんとう虫をご覧ください。

### バグ修正 🐞 
- 'Bundle ID' のないアプリを追加しようとした時の「**アプリ固有の設定**」でのクラッシュを修正。GitHub Issue [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289) と [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241) の解決に役立つかもしれません。
- Mac Mouse Fix が一部の**ペンタブレット**のスクロール動作を変更してしまう問題を修正。GitHub Issue [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249) を参照。
- 'A' キーを含む**キーボードショートカット**が記録できない問題を修正。GitHub Issue [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275) を修正。
- 標準以外のキーボードレイアウトを使用時に一部のボタン**リマッピング**が正しく機能しない問題を修正。
- **その他**の細かな修正と視覚的な改善。