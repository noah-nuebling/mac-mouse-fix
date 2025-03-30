Mac Mouse Fix **3.0.1** 帶來多項錯誤修復和改進，以及一個**新語言**！

### 新增越南語！

Mac Mouse Fix 現已支援 🇻🇳 越南語。特別感謝 @nghlt [在 GitHub 上](https://GitHub.com/nghlt)的貢獻！


### 錯誤修復

- Mac Mouse Fix 現在可以正常支援**快速用戶切換**！
  - 快速用戶切換是指在不登出第一個帳戶的情況下登入第二個 macOS 帳戶。
  - 在此更新之前，快速用戶切換後滾動功能會失效。現在所有功能都能正常運作。
- 修復了首次啟動 Mac Mouse Fix 時按鈕分頁佈局過寬的小問題。
- 改進了在快速連續新增多個動作時「+」欄位的可靠性。
- 修復了由 @V-Coba 在 Issue [735](https://github.com/noah-nuebling/mac-mouse-fix/issues/735) 中報告的一個罕見崩潰問題。

### 其他改進

- 使用「平滑度：一般」設定時，**滾動感覺更靈敏**。
  - 滾輪轉動越快，動畫速度就越快。這樣在快速滾動時感覺更靈敏，而在慢速滾動時仍然保持平滑。
  
- 使**滾動速度加速**更穩定和可預測。
- 實現了在更新到新版本 Mac Mouse Fix 時**保留設定**的機制。
  - 之前，如果設定結構發生變化，Mac Mouse Fix 會在更新到新版本後重置所有設定。現在，Mac Mouse Fix 會嘗試升級設定結構並保留你的偏好設定。
  - 目前這只適用於從 3.0.0 更新到 3.0.1。如果你從 3.0.0 之前的版本更新，或者從 3.0.1 _降級到_之前的版本，你的設定仍會被重置。
- 按鈕分頁的佈局現在能更好地適應不同語言的寬度。
- 改進了 [GitHub Readme](https://github.com/noah-nuebling/mac-mouse-fix#background) 和其他文件。
- 改進了本地化系統。翻譯文件現在會自動清理並分析潛在問題。新的[本地化指南](https://github.com/noah-nuebling/mac-mouse-fix/discussions/731)包含了自動檢測到的問題，以及為想幫助翻譯 Mac Mouse Fix 的人提供的其他有用信息和說明。移除了對 [BartyCrouch](https://github.com/FlineDev/BartyCrouch) 工具的依賴，該工具之前用於實現部分功能。
- 改進了多個英語和德語的界面文字。
- 大量底層清理和改進。

---

另外別忘了查看 [**3.0.0**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0) 的發布說明 - 這是 Mac Mouse Fix 迄今最大的更新！