Mac Mouse Fix **3.0.6** 改善了「上一頁」和「下一頁」功能，使其與更多應用程式相容。
此版本也修復了多個錯誤和問題。

### 改進的「上一頁」和「下一頁」功能

「上一頁」和「下一頁」滑鼠按鈕映射現在**可用於更多應用程式**，包括：

- Visual Studio Code、Cursor、VSCodium、Windsurf、Zed 和其他程式碼編輯器
- 許多內建的 Apple 應用程式，如預覽、備忘錄、系統設定、App Store 和音樂
- Adobe Acrobat
- Zotero
- 以及更多！

此實現受到 [LinearMouse](https://github.com/linearmouse/linearmouse) 優秀的「通用上一頁下一頁」功能啟發。它應該支援所有 LinearMouse 支援的應用程式。\
此外，它還支援一些通常需要鍵盤快捷鍵才能前後導航的應用程式，如系統設定、App Store、Apple 備忘錄和 Adobe Acrobat。Mac Mouse Fix 現在會偵測這些應用程式並模擬相應的鍵盤快捷鍵。

所有在 [GitHub Issue](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aclosed%20label%3A%22Universal%20Back%20and%20Forward%22) 中曾被要求支援的應用程式現在都應該能用了！（感謝回饋！）\
如果你發現任何應用程式仍然無法使用，請在[功能請求](http://redirect.macmousefix.com/?target=mmf-feedback-feature-request)中告訴我。

### 解決「滾動間歇性停止運作」的錯誤

一些使用者遇到[問題](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20state%3Aclosed%20stops%20working%20label%3A%22Scroll%20Stops%20Working%20Intermittently%22)，即**平滑滾動功能**會隨機停止運作。

雖然我從未能重現這個問題，但我已實施了可能的修復方案：

當設定顯示同步失敗時，應用程式現在會多次重試。\
如果重試後仍然無法運作，應用程式將：

- 重新啟動「Mac Mouse Fix Helper」背景程序，這可能會解決問題
- 產生當機報告，這可能有助於診斷錯誤

我希望問題現在已經解決！如果沒有，請在[錯誤報告](http://redirect.macmousefix.com/?target=mmf-feedback-bug-report)或通過[電子郵件](http://redirect.macmousefix.com/?target=mailto-noah)告訴我。

### 改進自由旋轉滾輪行為

當你在 MX Master 滑鼠（或任何其他具有自由旋轉滾輪的滑鼠）上讓滾輪自由旋轉時，Mac Mouse Fix **將不再加速滾動**。

雖然這個「滾動加速」功能在普通滾輪上很有用，但在自由旋轉滾輪上可能會使控制變得更困難。

**注意：** Mac Mouse Fix 目前與大多數羅技滑鼠（包括 MX Master）尚未完全相容。我計劃添加完整支援，但可能需要一段時間。在此期間，我所知道的最好的具有羅技支援的第三方驅動程式是 [SteerMouse](https://plentycom.jp/en/steermouse/)。

### 錯誤修復

- 修復了 Mac Mouse Fix 有時會重新啟用先前在系統設定中停用的鍵盤快捷鍵的問題
- 修復了點擊「啟用授權」時的當機問題
- 修復了在點擊「啟用授權」後立即點擊「取消」時的當機問題（感謝回報，Ali！）
- 修復了在 Mac 未連接顯示器時嘗試使用 Mac Mouse Fix 時的當機問題
- 修復了在應用程式中切換分頁時的記憶體洩漏和其他底層問題

### 視覺改進

- 修復了在 [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5) 中引入的「關於」分頁有時過高的問題
- 「免費天數已結束」通知中的中文文字不再被截斷
- 修復了錄製輸入後「+」欄位陰影的視覺問題
- 修復了「輸入授權金鑰」畫面上的預設文字有時會偏離中心的罕見問題
- 修復了在深色/淺色模式之間切換後，應用程式中顯示的某些符號顏色錯誤的問題

### 其他改進

- 使某些動畫（如分頁切換動畫）略微更有效率
- 在「輸入授權金鑰」畫面上停用 Touch Bar 文字完成功能
- 各種較小的底層改進

*在 Claude 的出色協助下編輯。*

---

另請查看先前的版本 [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5)。