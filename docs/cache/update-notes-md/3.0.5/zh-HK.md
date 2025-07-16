**ℹ️ Mac Mouse Fix 2 用戶須知**

隨著 Mac Mouse Fix 3 的推出，應用程式的定價模式有所改變：

- **Mac Mouse Fix 2**\
仍然完全免費，我計劃繼續支援。\
**跳過此更新**以繼續使用 Mac Mouse Fix 2。在[這裡](https://redirect.macmousefix.com/?target=mmf2-latest)下載最新版本的 Mac Mouse Fix 2。
- **Mac Mouse Fix 3**\
30天免費試用，永久使用需付費幾美元。\
**立即更新**以獲取 Mac Mouse Fix 3！

你可以在[新網站](https://macmousefix.com/)了解更多關於 Mac Mouse Fix 3 的定價和功能。

感謝使用 Mac Mouse Fix！:)

---

**ℹ️ Mac Mouse Fix 3 購買者須知**

如果你在不知道軟件已改為付費的情況下意外更新到 Mac Mouse Fix 3，我願意為你提供[退款](https://redirect.macmousefix.com/?target=mmf-apply-for-refund)。

Mac Mouse Fix 2 的最新版本仍然**完全免費**，你可以在[這裡](https://redirect.macmousefix.com/?target=mmf2-latest)下載。

為造成的不便深表歉意，希望大家能接受這個解決方案！

---

Mac Mouse Fix **3.0.5** 修復了多個錯誤，提升了性能，並為應用程式增添了一些改進。\
同時也支援 macOS 26 Tahoe。

### 改進觸控板滾動模擬

- 滾動系統現在可以模擬觸控板的雙指輕點來使應用程式停止滾動。
    - 這修復了在運行 iPhone 或 iPad 應用程式時，用戶停止滾動後經常會繼續滾動的問題。
- 修復了模擬手指離開觸控板時的不一致問題。
    - 這可能在某些情況下導致非最佳表現。

### macOS 26 Tahoe 兼容性

在運行 macOS 26 Tahoe Beta 版時，應用程式現在可以使用，且大部分界面都能正常運作。

### 性能提升

改進了點擊並拖動以"滾動和導航"手勢的性能。\
根據我的測試，CPU 使用率降低了約 50%！

**背景**

在"滾動和導航"手勢期間，Mac Mouse Fix 會在透明窗口中繪製一個假的滑鼠游標，同時將真實游標鎖定在原位。這確保你無論將滑鼠移動多遠，都可以繼續滾動最初選定的界面元素。\

通過關閉這個透明窗口上原本未使用的 macOS 默認事件處理，實現了性能的提升。

### 錯誤修復

- 現在會忽略 Wacom 繪圖板的滾動事件。
    - 之前，Mac Mouse Fix 導致 Wacom 繪圖板出現不穩定的滾動，如 @frenchie1980 在 GitHub Issue [#1233](https://github.com/noah-nuebling/mac-mouse-fix/issues/1233) 中報告的那樣。（謝謝！）
    
- 修復了在 Mac Mouse Fix 3.0.4 中引入的新授權系統中，Swift Concurrency 代碼未在正確線程上運行的錯誤。
    - 這導致在 macOS Tahoe 上崩潰，也可能導致其他與授權相關的零星錯誤。
- 改進了離線授權解碼代碼的穩定性。
    - 這解決了 Apple API 的一個問題，該問題導致在我的 Intel Mac Mini 上離線授權驗證總是失敗。我猜測這在所有 Intel Mac 上都會發生，這也可能是為什麼"免費天數已結束"錯誤（在 3.0.4 中已解決）仍然發生在一些用戶身上，如 @toni20k5267 在 GitHub Issue [#1356](https://github.com/noah-nuebling/mac-mouse-fix/issues/1356) 中報告的那樣。（謝謝！）

### 用戶體驗改進

- 禁用了為解決阻止用戶啟用 Mac Mouse Fix 的 macOS 錯誤而提供的逐步解決方案對話框。
    - 這些問題只在 macOS 13 Ventura 和 14 Sonoma 上出現。現在，這些對話框只會在相關的 macOS 版本上顯示。
    - 這些對話框也更難觸發 – 之前它們有時會在不太有幫助的情況下顯示。
    
- 在"免費天數已結束"通知上直接添加了"啟用授權"鏈接。
    - 這使啟用 Mac Mouse Fix 授權變得更加方便簡單。

### 視覺改進

- 稍微改進了"軟件更新"窗口的外觀。現在更適合 macOS 26 Tahoe。
    - 這是通過自定義 Mac Mouse Fix 用於處理更新的"Sparkle 1.27.3"框架的默認外觀實現的。
- 通過略微加寬窗口，修復了"關於"標籤頁底部的文字在中文環境下有時會被截斷的問題。
- 修復了"關於"標籤頁底部文字的居中問題。
- 修復了導致"按鈕"標籤頁上"鍵盤快捷鍵..."選項下方空間過小的錯誤。

### 底層更改

- 移除了對"SnapKit"框架的依賴
    - 這使應用程式的大小從 19.8 MB 略微降低到 19.5 MB
- 代碼庫中的其他各種小改進。

*在 Claude 的出色協助下編輯。*

---

另請查看之前的版本 [**3.0.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.4)。