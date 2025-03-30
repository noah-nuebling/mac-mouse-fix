Mac Mouse Fix **2.2.4**がAppleの公証を取得しました！また、いくつかの小さなバグ修正やその他の改善も含まれています。

### **公証について**

Mac Mouse Fix 2.2.4がAppleによって「公証」されました。これにより、初めてアプリを開く際に表示される「悪意のあるソフトウェア」である可能性についての警告メッセージが表示されなくなります。

#### 背景

アプリの公証には年間100ドルの費用がかかります。Mac Mouse Fixのような無料でオープンソースのソフトウェアに対して敵対的に感じられ、またAppleがiPhoneやiPadのようにMacを管理・制限する危険な一歩だと感じていたため、これまで反対していました。しかし、公証がないことで[アプリを開くのが困難](https://github.com/noah-nuebling/mac-mouse-fix/discussions/114)になったり、[新バージョンをリリースするまで誰もアプリを使用できない状況](https://github.com/noah-nuebling/mac-mouse-fix/issues/95)が発生するなど、様々な問題が生じていました。

Mac Mouse Fix 3は収益化されているため、年間100ドルを支払って公証を取得することが適切だと考えました。([詳細](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0)) \
今回、Mac Mouse Fix 2も公証を取得し、より簡単で安定したユーザー体験を提供できるようになりました。

### **バグ修正**

- 画面録画中や[DisplayLink](https://www.synaptics.com/products/displaylink-graphics)ソフトウェアの使用中に「クリック＆ドラッグ」アクションを使用した際、カーソルが消えて別の場所に再表示される問題を修正しました。
- macOS 10.14 Mojaveおよびそれより古いmacOSバージョンでMac Mouse Fixを有効化する際の問題を修正しました。
- メモリ管理を改善し、マウスをコンピュータから取り外した際に発生する可能性のある「Mac Mouse Fix Helper」アプリのクラッシュを修正しました。ディスカッション[#771](https://github.com/noah-nuebling/mac-mouse-fix/discussions/771)を参照してください。

### **その他の改善点**

- Mac Mouse Fixの新バージョンが利用可能であることを通知するウィンドウがJavaScriptをサポートするようになりました。これにより、アップデート情報がより見やすく読みやすくなりました。例えば、[Markdownアラート](https://github.com/orgs/community/discussions/16925)などが表示できるようになりました。
- 「Mac Mouse Fix Helperにアクセシビリティアクセスを許可する」画面からhttps://macmousefix.com/about/へのリンクを削除しました。これは、Aboutページが存在しなくなり、現在は[GitHubのReadme](https://github.com/noah-nuebling/mac-mouse-fix)に置き換えられているためです。
- このリリースにはdSYMファイルが含まれており、Mac Mouse Fix 2.2.4のクラッシュレポートを誰でもデコードできるようになりました。
- その他、内部的なクリーンアップと改善を行いました。

---

前回のリリース[**2.2.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.3)もご確認ください。