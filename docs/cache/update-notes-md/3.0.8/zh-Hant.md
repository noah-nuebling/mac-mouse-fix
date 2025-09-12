Mac Mouse Fix **3.0.8** 修復了使用者介面問題及其他功能。

### **使用者介面問題**

- 修復了「免費試用期已結束」通知卡在螢幕角落的錯誤。
    - 對於這個錯誤我深感抱歉！希望沒有造成太多困擾。感謝 [Sashpuri](https://github.com/Sashpuri) 和其他人回報此問題。
- 在 macOS 26 Tahoe 上停用新設計。現在應用程式的外觀和功能將與 macOS 15 Sequoia 上的版本相同。
    - 這是因為 Apple 部分重新設計的使用者介面元素尚未正常運作，導致「按鈕」分頁出現一些問題。例如，「-」按鈕有時無法點擊。
    - 現在在 macOS 26 Tahoe 上的使用者介面可能看起來有點過時。但它應該能像以前一樣完全正常運作且精緻完善 – 我認為這對使用者來說更重要。

### **使用者介面優化**

- 停用 Mac Mouse Fix 主視窗中的綠色視窗按鈕。
    - 這個按鈕是多餘的。因為視窗無法手動調整大小，所以它實際上沒有任何作用。
- 修復了在 macOS 26 Tahoe 下「按鈕」分頁中某些水平線條過暗的問題。
- 修復了在 macOS 26 Tahoe 下「按鈕」分頁中「無法使用主要滑鼠按鈕」訊息有時會被截斷的錯誤。
- 修正了德文介面中的錯字。感謝 GitHub 用戶 [i-am-the-slime](https://github.com/i-am-the-slime)。
- 解決了在 macOS 26 Tahoe 上開啟視窗時，MMF 視窗有時會短暫閃現錯誤大小的問題。

### **其他更改**

- 改善了當電腦上執行多個 Mac Mouse Fix 實例時，嘗試啟用 Mac Mouse Fix 的行為。
    - Mac Mouse Fix 現在會更加努力地嘗試停用其他 Mac Mouse Fix 實例。
    - 這可能會改善某些之前無法啟用 Mac Mouse Fix 的特殊情況。
- 底層更改和清理。

---

另外也請查看上一個版本 [3.0.7](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.7)。