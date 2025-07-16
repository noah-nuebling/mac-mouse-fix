Mac Mouse Fix **3.0.4** 改進了私隱保護、效能和可靠性。\
它引入了全新的離線授權系統，並修復了多個重要錯誤。

### 增強私隱保護和效能

3.0.4 引入了新的離線授權驗證系統，盡可能減少互聯網連接。\
這提升了私隱保護並節省電腦系統資源。\
獲得授權後，應用程式現在可以100%離線運作！

<details>
<summary><b>點擊此處查看更多詳情</b></summary>
之前的版本在每次啟動時都會在線驗證授權，這可能會讓第三方伺服器（GitHub 和 Gumroad）儲存連接記錄。新系統消除了不必要的連接 – 在初次授權啟用後，只有在本地授權數據損壞時才會連接互聯網。
<br><br>
雖然我本人從未記錄任何用戶行為，但舊系統理論上允許第三方伺服器記錄 IP 地址和連接時間。Gumroad 還可以記錄你的授權金鑰，並可能將其與你購買 Mac Mouse Fix 時他們記錄的個人信息關聯起來。
<br><br>
在建立原始授權系統時我並未考慮這些細微的私隱問題，但現在，Mac Mouse Fix 已經盡可能做到私密且無需互聯網連接！
<br><br>
另請參閱 <a href=https://gumroad.com/privacy>Gumroad 的私隱政策</a>和我的這條 <a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>GitHub 評論</a>。

</details>

### 錯誤修復

- 修復了使用「點擊並拖曳」來控制「空間和調度中心」時，macOS 有時會卡住的錯誤。
- 修復了使用 Mac Mouse Fix 的「點擊」動作（如「調度中心」）時，系統設定中的鍵盤快捷鍵有時會被刪除的錯誤。
- 修復了[一個錯誤](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22)，該錯誤導致已購買應用程式的用戶有時會收到「免費試用期已結束」的通知，且應用程式停止運作。
    - 如果你遇到這個錯誤，我真誠地為帶來的不便道歉。你可以在[這裡申請退款](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund)。
- 改進了應用程式獲取主視窗的方式，這可能修復了「啟用授權」畫面有時無法顯示的錯誤。

### 可用性改進

- 在「啟用授權」畫面的文字輸入框中禁止輸入空格和換行。
    - 這是一個常見的困擾點，因為從 Gumroad 的電子郵件中複製授權金鑰時很容易不小心選中隱藏的換行符。
- 這些更新說明會自動為非英語用戶翻譯（由 Claude 提供支援）。希望這對你有幫助！如果你遇到任何問題，請告訴我。這是我過去一年開發的新翻譯系統的初步展示。

### 停止（非官方）支援 macOS 10.14 Mojave

Mac Mouse Fix 3 官方支援 macOS 11 Big Sur 及更新版本。然而，對於願意接受一些故障和圖形問題的用戶，Mac Mouse Fix 3.0.3 及更早版本仍可在 macOS 10.14.4 Mojave 上使用。

Mac Mouse Fix 3.0.4 停止了該支援，**現在需要 macOS 10.15 Catalina**。\
為此帶來的不便我深表歉意。這個改變讓我能夠使用現代 Swift 功能來實現改進的授權系統。Mojave 用戶可以繼續使用 Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) 或 [Mac Mouse Fix 2 的最新版本](https://redirect.macmousefix.com/?target=mmf2-latest)。希望這能為大家提供一個好的解決方案。

### 底層改進

- 實現了新的「MFDataClass」系統，在保持 Mac Mouse Fix 配置文件可讀性和可編輯性的同時，實現更強大的數據建模。
- 建立了支援除 Gumroad 外其他支付平台的功能。因此將來可能會有本地化結帳，應用程式也可以銷售到不同國家。
- 改進了日誌記錄，使我能為遇到難以重現錯誤的用戶創建更有效的「調試版本」。
- 許多其他小改進和清理工作。

*在 Claude 的出色協助下編輯。*

---

另請查看之前的版本 [**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3)。