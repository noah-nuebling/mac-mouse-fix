也別忘了看看 [3.0.0 Beta 4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-4) 中引入的**精彩更新**！

---

**3.0.0 Beta 5** 恢復了在 macOS 13 Ventura 下某些**滑鼠**的**相容性**，並**修復**了許多應用程式中的**捲動問題**。
此外還包含了一些小修復和使用體驗改進。

以下是**所有新功能**：

### 滑鼠

- 修復了在終端機和其他應用程式中的捲動問題！詳見 GitHub Issue [#413](https://github.com/noah-nuebling/mac-mouse-fix/issues/413)。
- 透過捨棄不可靠的 Apple API 轉而使用底層技術，修復了在 macOS 13 Ventura 下某些滑鼠的不相容問題。希望這不會帶來新的問題 - 如果有的話請告訴我！特別感謝 Maria 和 GitHub 用戶 [samiulhsnt](https://github.com/samiulhsnt) 協助解決這個問題！更多資訊請參見 GitHub Issue [#424](https://github.com/noah-nuebling/mac-mouse-fix/issues/424)。
- 點擊滑鼠按鈕 1 或 2 時不再消耗 CPU。點擊其他按鈕時的 CPU 使用率也略有降低。
    - 這是「除錯版本」，所以在此測試版中點擊按鈕時的 CPU 使用率可能比正式版本高約 10 倍
- 用於 Mac Mouse Fix 的「平滑捲動」和「捲動與導航」功能的觸控板捲動模擬現在更加精確。這可能會在某些情況下帶來更好的體驗。

### 使用者介面

- 自動修復從舊版本 Mac Mouse Fix 更新後授予輔助功能存取權限的問題。採用了 [2.2.2 版本說明](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.2) 中描述的更改。
- 在「授予輔助功能存取權限」畫面中新增「取消」按鈕
- 修復了安裝新版本 Mac Mouse Fix 後，由於新版本連接到舊版「Mac Mouse Fix Helper」而導致配置無法正常運作的問題。現在，Mac Mouse Fix 將不再連接到舊版「Mac Mouse Fix Helper」，並在適當時候自動停用舊版本。
- 為使用者提供如何修復由於系統中存在其他版本的 Mac Mouse Fix 而導致無法正常啟用的問題的說明。此問題僅在 macOS Ventura 下出現。
- 改進「授予輔助功能存取權限」畫面的行為和動畫
- 啟用 Mac Mouse Fix 時會將其帶到前台。這改善了某些情況下的使用者介面互動，例如在系統設定 > 一般 > 登入項目中停用後重新啟用 Mac Mouse Fix 時。
- 改進「授予輔助功能存取權限」畫面的使用者介面文字
- 改進嘗試啟用 Mac Mouse Fix 時系統設定中停用的提示文字
- 修復了一處德文使用者介面文字

### 底層更新

- 「Mac Mouse Fix」和內嵌的「Mac Mouse Fix Helper」的版本編號現在已同步。這用於防止「Mac Mouse Fix」意外連接到舊版本的「Mac Mouse Fix Helper」。
- 透過移除初始配置中的快取資料，修復了首次啟動應用程式時有關授權和試用期的某些資料有時顯示不正確的問題
- 大量清理專案結構和原始碼
- 改進除錯訊息

---

### 如何幫助我們

你可以透過分享你的**想法**、**問題**和**回饋**來幫助我們！

分享**想法**和**問題**的最佳地點是[回饋助手](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report)。
提供**快速**非結構化回饋的最佳地點是[回饋討論](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366)。

你也可以在應用程式的「**ⓘ 關於**」分頁中存取這些位置。

**感謝**你協助改進 Mac Mouse Fix！💙💛❤️