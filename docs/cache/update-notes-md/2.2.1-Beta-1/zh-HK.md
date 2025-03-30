### Ventura 支援！
Mac Mouse Fix 現已完全支援 macOS 13 Ventura。
特別感謝 [@chamburr](https://github.com/chamburr) 在 GitHub Issue [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297) 中協助提供 Ventura 支援。

### 停止支援較舊的 macOS 版本

可惜的是，在使用 macOS 13 Ventura 進行開發時，Apple 只允許開發支援 macOS 10.13 **High Sierra 及以上版本**的軟件。

因此，**最低支援版本**已從 10.11 El Capitan 提升至 10.13 High Sierra。

對此我深感抱歉。不過下一節有一隻悠閒的瓢蟲可以讓你心情好一點。

### 錯誤修復 🐞 
- 修復了在「**App 專用設定**」中嘗試添加沒有「Bundle ID」的應用程式時造成的崩潰問題。可能有助於解決 GitHub Issues [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289) 和 [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241)。
- 修復了 Mac Mouse Fix 改變某些**繪圖板**滾動行為的問題。詳見 GitHub Issue [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249)。
- 修復了無法記錄包含「A」鍵的**鍵盤快捷鍵**的問題。修復了 GitHub Issue [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275)。
- 修復了使用非標準鍵盤布局時某些按鈕**重新映射**無法正常工作的問題。
- **其他**小修復和視覺改進。