Mac Mouse Fix **2.2.1** 版本為 **macOS Ventura** 提供完整支援及其他更新。

### Ventura 支援！
Mac Mouse Fix 現已完全支援 macOS 13 Ventura，並提供原生體驗。
特別感謝 [@chamburr](https://github.com/chamburr) 在 GitHub Issue [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297) 中協助 Ventura 支援。

更新包括：

- 更新了授予輔助使用權限的介面，以配合新的 Ventura 系統設定
- Mac Mouse Fix 將在 Ventura 的新 **系統設定 > 登入項目** 選單中正確顯示
- Mac Mouse Fix 將在 **系統設定 > 登入項目** 中被停用時作出適當反應

### 停止支援較舊的 macOS 版本

可惜的是，在 macOS 13 Ventura 環境下開發時，Apple 只允許開發支援 macOS 10.13 **High Sierra 或以上版本**的應用程式。

因此，**最低支援版本**已從 10.11 El Capitan 提升至 10.13 High Sierra。

### 錯誤修復

- 修復了 Mac Mouse Fix 改變某些**繪圖板**滾動行為的問題。詳見 GitHub Issue [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249)。
- 修復了無法記錄包含 'A' 鍵的**鍵盤快捷鍵**的問題。修復 GitHub Issue [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275)。
- 修復了使用非標準鍵盤布局時某些**按鈕重新映射**無法正常運作的問題。
- 修復了在「**應用程式專用設定**」中嘗試添加沒有「Bundle ID」的應用程式時造成崩潰的問題。可能有助於解決 GitHub Issue [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289)。
- 修復了在「**應用程式專用設定**」中嘗試添加沒有名稱的應用程式時造成崩潰的問題。解決 GitHub Issue [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241)。特別感謝 [jeongtae](https://github.com/jeongtae) 在找出問題原因時提供的寶貴幫助！
- 其他小錯誤修復和內部改進。