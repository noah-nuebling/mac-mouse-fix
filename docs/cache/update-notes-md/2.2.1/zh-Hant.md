Mac Mouse Fix **2.2.1** 版本提供完整的 **macOS Ventura 支援**及其他更新。

### Ventura 支援！
Mac Mouse Fix 現已完整支援 macOS 13 Ventura，並提供原生體驗。
特別感謝 [@chamburr](https://github.com/chamburr) 在 GitHub Issue [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297) 中協助 Ventura 支援。

更新內容包括：

- 更新授予輔助使用權限的使用者介面，以配合新版 Ventura 系統設定
- Mac Mouse Fix 將在 Ventura 新的**系統設定 > 登入項目**選單中正確顯示
- Mac Mouse Fix 將在**系統設定 > 登入項目**中停用時正確回應

### 停止支援舊版 macOS

很遺憾，在 macOS 13 Ventura 環境下開發時，Apple 僅允許開發支援 **macOS 10.13 High Sierra 或更新版本**的應用程式。

因此，**最低支援版本**已從 10.11 El Capitan 提升至 10.13 High Sierra。

### 錯誤修復

- 修復 Mac Mouse Fix 改變某些**繪圖板**捲動行為的問題。參見 GitHub Issue [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249)。
- 修復無法記錄包含 'A' 鍵的**鍵盤快捷鍵**的問題。修復 GitHub Issue [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275)。
- 修復使用非標準鍵盤配置時某些**按鈕重新映射**無法正常運作的問題。
- 修復在「**應用程式專用設定**」中嘗試新增沒有 'Bundle ID' 的應用程式時造成崩潰的問題。可能有助於解決 GitHub Issue [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289)。
- 修復在「**應用程式專用設定**」中嘗試新增沒有名稱的應用程式時造成崩潰的問題。解決 GitHub Issue [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241)。特別感謝 [jeongtae](https://github.com/jeongtae) 協助找出問題！
- 其他小錯誤修復和內部改進。