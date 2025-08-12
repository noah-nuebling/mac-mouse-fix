**ℹ️ Mac Mouse Fix 2 用戶須知**

隨著 Mac Mouse Fix 3 的推出，應用程式的定價模式有所改變：

- **Mac Mouse Fix 2**\
仍然完全免費，我計劃繼續支援。\
**跳過此更新**以繼續使用 Mac Mouse Fix 2。在[這裡](https://redirect.macmousefix.com/?target=mmf2-latest)下載最新版本的 Mac Mouse Fix 2。
- **Mac Mouse Fix 3**\
30天免費試用，之後需要支付少許費用。\
**立即更新**以獲取 Mac Mouse Fix 3！

你可以在[新網站](https://macmousefix.com/)了解更多關於 Mac Mouse Fix 3 的定價和功能。

感謝使用 Mac Mouse Fix！:)

---

**ℹ️ Mac Mouse Fix 3 購買者須知**

如果你在不知道新版本需要付費的情況下意外更新到 Mac Mouse Fix 3，我願意提供[退款](https://redirect.macmousefix.com/?target=mmf-apply-for-refund)。

Mac Mouse Fix 2 的最新版本仍然**完全免費**，你可以在[這裡](https://redirect.macmousefix.com/?target=mmf2-latest)下載。

為造成的不便深表歉意，希望大家能接受這個解決方案！

---

Mac Mouse Fix **3.0.6** 使「返回」和「前進」功能支援更多應用程式。
同時修復了多個錯誤和問題。

### 改進的「返回」和「前進」功能

「返回」和「前進」滑鼠按鈕映射現在**支援更多應用程式**，包括：

- Visual Studio Code、Cursor、VSCodium、Windsurf、Zed 和其他程式編輯器
- 許多 Apple 內置應用程式，如預覽、備忘錄、系統設定、App Store 和音樂
- Adobe Acrobat
- Zotero
- 以及更多！

此實現受到 [LinearMouse](https://github.com/linearmouse/linearmouse) 出色的「通用返回和前進」功能啟發。它應該支援所有 LinearMouse 支援的應用程式。\
此外，它還支援一些通常需要鍵盤快捷鍵才能返回和前進的應用程式，如系統設定、App Store、Apple 備忘錄和 Adobe Acrobat。Mac Mouse Fix 現在會檢測這些應用程式並模擬相應的鍵盤快捷鍵。

所有在 [GitHub Issues](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aclosed%20label%3A%22Universal%20Back%20and%20Forward%22) 中曾被要求支援的應用程式現在都應該支援了！（感謝反饋！）\
如果你發現任何應用程式仍然不能使用，請在[功能請求](http://redirect.macmousefix.com/?target=mmf-feedback-feature-request)中告訴我。

### 解決「滾動間歇性停止工作」的錯誤

一些用戶遇到了[問題](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20state%3Aclosed%20stops%20working%20label%3A%22Scroll%20Stops%20Working%20Intermittently%22)，**平滑滾動**會隨機停止工作。

雖然我從未能重現這個問題，但我已實施了一個可能的修復方案：

當設置顯示同步失敗時，應用程式現在會多次重試。\
如果重試後仍然無法工作，應用程式將：

- 重啟「Mac Mouse Fix Helper」背景進程，這可能會解決問題
- 生成崩潰報告，這可能有助於診斷錯誤

希望問題現在已經解決！如果沒有，請在[錯誤報告](http://redirect.macmousefix.com/?target=mmf-feedback-bug-report)或通過[電郵](http://redirect.macmousefix.com/?target=mailto-noah)告訴我。

### 改進自由旋轉滾輪行為

當你在 MX Master 滑鼠（或任何其他帶有自由旋轉滾輪的滑鼠）上讓滾輪自由旋轉時，Mac Mouse Fix **不再加速滾動**。

雖然這個「滾動加速」功能在普通滾輪上很有用，但在自由旋轉滾輪上可能會使控制變得更困難。

**注意：** Mac Mouse Fix 目前與大多數羅技滑鼠（包括 MX Master）不完全相容。我計劃添加完整支援，但可能需要一段時間。在此期間，我所知道的最好的第三方驅動程式是 [SteerMouse](https://plentycom.jp/en/steermouse/)。

### 錯誤修復

- 修復了 Mac Mouse Fix 有時會重新啟用之前在系統設定中禁用的鍵盤快捷鍵的問題
- 修復了點擊「啟用授權」時的崩潰
- 修復了點擊「啟用授權」後立即點擊「取消」時的崩潰（感謝 Ali 的報告！）
- 修復了在 Mac 未連接顯示器時嘗試使用 Mac Mouse Fix 時的崩潰
- 修復了在應用程式中切換標籤時的內存洩漏和其他底層問題

### 視覺改進

- 修復了在 [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5) 中引入的「關於」標籤有時過高的問題
- 中文版「免費試用期已結束」通知的文字不再被截斷
- 修復了記錄輸入後「+」欄位陰影的視覺問題
- 修復了「輸入授權碼」畫面上佔位文字偶爾會出現偏離中心的問題
- 修復了在深色/淺色模式之間切換後，應用程式中顯示的某些符號顏色錯誤的問題

### 其他改進

- 使某些動畫（如標籤切換動畫）略微更加高效
- 在「輸入授權碼」畫面上禁用 Touch Bar 文字補全
- 各種較小的底層改進

*在 Claude 的出色協助下編輯。*

---

另請查看之前的版本 [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5)