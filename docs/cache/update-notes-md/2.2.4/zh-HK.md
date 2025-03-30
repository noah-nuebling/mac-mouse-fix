Mac Mouse Fix **2.2.4** 現已通過公證！此版本還包含一些小錯誤修復和其他改進。

### **公證**

Mac Mouse Fix 2.2.4 現已獲得 Apple 的「公證」。這意味著首次打開應用程式時，不會再出現關於 Mac Mouse Fix 可能是「惡意軟件」的提示訊息。

#### 背景

應用程式公證每年需要支付 100 美元。我一直反對這做法，因為這對免費和開源軟件（如 Mac Mouse Fix）並不友善，而且感覺這是 Apple 想要像控制 iPhone 或 iPad 一樣控制和封鎖 Mac 的危險舉措。但缺乏公證也帶來了不同的問題，包括[打開應用程式時的困難](https://github.com/noah-nuebling/mac-mouse-fix/discussions/114)，甚至出現[多種情況](https://github.com/noah-nuebling/mac-mouse-fix/issues/95)導致所有用戶都無法使用該應用程式，直到我發布新版本為止。

對於 Mac Mouse Fix 3，由於它已經商業化，我認為每年支付 100 美元進行公證是合適的。（[了解更多](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0)）\
現在，Mac Mouse Fix 2 也獲得了公證，這應該會帶來更簡便和穩定的用戶體驗。

### **錯誤修復**

- 修復了在螢幕錄製期間或使用 [DisplayLink](https://www.synaptics.com/products/displaylink-graphics) 軟件時，使用「點擊並拖曳」動作會導致游標消失然後在不同位置重新出現的問題。
- 修復了在 macOS 10.14 Mojave 和可能更舊的 macOS 版本中啟用 Mac Mouse Fix 的問題。
- 改進了記憶體管理，可能修復了在從電腦拔除滑鼠時「Mac Mouse Fix Helper」應用程式崩潰的問題。參見討論 [#771](https://github.com/noah-nuebling/mac-mouse-fix/discussions/771)。

### **其他改進**

- 應用程式顯示新版本更新提示的視窗現在支援 JavaScript。這使更新說明更美觀且更易於閱讀。例如，更新說明現在可以顯示 [Markdown 提示](https://github.com/orgs/community/discussions/16925) 等內容。
- 從「授予 Mac Mouse Fix Helper 輔助功能權限」畫面中移除了指向 https://macmousefix.com/about/ 頁面的連結。這是因為關於頁面已不存在，目前已被 [GitHub Readme](https://github.com/noah-nuebling/mac-mouse-fix) 取代。
- 此版本現包含 dSYM 文件，任何人都可以用它來解碼 Mac Mouse Fix 2.2.4 的崩潰報告。
- 一些內部清理和改進。

---

另請查看先前的版本 [**2.2.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.3)。