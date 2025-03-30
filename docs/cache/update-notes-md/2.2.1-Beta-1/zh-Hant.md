### Ventura 支援！
Mac Mouse Fix 現已完整支援 macOS 13 Ventura。
特別感謝 [@chamburr](https://github.com/chamburr) 在 GitHub Issue [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297) 中協助 Ventura 支援。

### 停止支援較舊的 macOS 版本

很遺憾，在使用 macOS 13 Ventura 進行開發時，Apple 只允許開發支援 macOS 10.13 **High Sierra 及更新版本**的應用程式。

因此，**最低支援版本**已從 10.11 El Capitan 提升至 10.13 High Sierra。

對此我深感抱歉。不過下一節有一隻悠閒的瓢蟲可以讓你心情好一點。

### 錯誤修復 🐞 
- 修復了在「**應用程式專用設定**」中，嘗試新增沒有「Bundle ID」的應用程式時造成的當機問題。可能有助於解決 GitHub Issues [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289) 和 [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241)。
- 修復了 Mac Mouse Fix 改變某些**繪圖板**捲動行為的問題。參見 GitHub Issue [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249)。
- 修復了無法記錄包含「A」鍵的**鍵盤快捷鍵**的問題。修復 GitHub Issue [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275)。
- 修復了使用非標準鍵盤配置時，某些按鈕**重新映射**無法正常運作的問題。
- **其他**小修復和視覺改進。