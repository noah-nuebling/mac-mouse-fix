Mac Mouse Fix **2.2.1**では、その他の変更とともに**macOS Venturaの完全サポート**を提供します。

### Venturaサポート！
Mac Mouse Fixは、macOS 13 Venturaを完全にサポートし、ネイティブな使用感を実現しました。
GitHub Issue [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297)でVenturaサポートに協力してくれた[@chamburr](https://github.com/chamburr)に特別な感謝を捧げます。

変更点：

- アクセシビリティアクセスを許可するUIを新しいVenturaのシステム設定に合わせて更新
- Venturaの新しい**システム設定 > ログイン項目**メニューでMac Mouse Fixが適切に表示されるように
- **システム設定 > ログイン項目**で無効化された際に適切に反応するように

### 古いmacOSバージョンのサポート終了

残念ながら、macOS 13 Venturaで開発する場合、Appleは10.13 **High Sierra以降**のmacOSに対する開発のみを許可しています。

そのため、**最小サポートバージョン**が10.11 El Capitanから10.13 High Sierraに引き上げられました。

### バグ修正

- Mac Mouse Fixが一部の**ペンタブレット**のスクロール動作を変更してしまう問題を修正。GitHub Issue [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249)を参照。
- 'A'キーを含む**キーボードショートカット**が記録できない問題を修正。GitHub Issue [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275)を修正。
- 標準以外のキーボードレイアウトを使用時に一部の**ボタン割り当て**が正しく機能しない問題を修正。
- 'Bundle ID'のないアプリを'**アプリ固有の設定**'に追加しようとした際のクラッシュを修正。GitHub Issue [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289)の解決に役立つ可能性があります。
- 名前のないアプリを'**アプリ固有の設定**'に追加しようとした際のクラッシュを修正。GitHub Issue [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241)を解決。問題の解明に大きく貢献してくれた[jeongtae](https://github.com/jeongtae)に特別な感謝を捧げます！
- その他の小さなバグ修正と内部的な改善。