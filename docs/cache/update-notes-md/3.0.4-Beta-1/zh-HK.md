Mac Mouse Fix **3.0.4 Beta 1** 改進了私隱保護、效能和可靠性。\
它引入了全新的離線授權系統，並修復了多個重要錯誤。

### 加強私隱保護和效能

- 引入新的離線授權驗證系統，減少互聯網連接。
- 應用程式現在只在絕對必要時才會連接互聯網，保護你的私隱並減少資源使用。
- 授權後的正常使用完全無需連接互聯網。

<details>
<summary><b>詳細私隱資訊</b></summary>
舊版本在每次啟動時都會在線驗證授權，這可能導致第三方伺服器（GitHub 和 Gumroad）儲存連接記錄。新系統消除了不必要的連接 – 在首次授權啟用後，只有在本地授權數據損壞時才會連接互聯網。
<br><br>
雖然我本人從未記錄任何用戶行為，但舊系統理論上允許第三方伺服器記錄 IP 地址和連接時間。Gumroad 還可能記錄你的授權金鑰，並可能將其與你購買時提供的個人資料關聯起來。
<br><br>
在建立原始授權系統時我沒有考慮到這些細微的私隱問題，但現在，Mac Mouse Fix 已經盡可能做到私密和無需連接互聯網！
<br><br>
另請參閱 <a href=https://gumroad.com/privacy>Gumroad 的私隱政策</a>和我的這個 <a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>GitHub 評論</a>。

</details>

### 錯誤修復

- 修復了使用「點擊並拖曳」來控制「空間和調度中心」時，macOS 有時會卡住的錯誤。
- 修復了使用 Mac Mouse Fix 中定義的「點擊」動作（如「調度中心」）時，系統設定中的鍵盤快捷鍵有時會被刪除的錯誤。
- 修復了[一個錯誤](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22)，已購買應用程式的用戶有時會收到「免費試用期已結束」的通知，且應用程式停止運作。
    - 如果你遇到這個錯誤，我真誠地向你道歉。你可以在[這裡申請退款](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund)。

### 技術改進

- 實現了新的「MFDataClass」系統，實現更清晰的數據建模和人類可讀的配置文件。
- 建立了支援除 Gumroad 外其他支付平台的功能。未來可能會提供本地化結帳，應用程式也可能在不同國家銷售！

### 停止（非官方）支援 macOS 10.14 Mojave

Mac Mouse Fix 3 官方支援 macOS 11 Big Sur 及更新版本。然而，對於願意接受一些故障和圖形問題的用戶，Mac Mouse Fix 3.0.3 及更早版本仍可在 macOS 10.14.4 Mojave 上使用。

Mac Mouse Fix 3.0.4 停止了這項支援，**現在需要 macOS 10.15 Catalina**。\
對此造成的不便我深表歉意。這項改變讓我能夠使用現代 Swift 功能來實現改進的授權系統。Mojave 用戶可以繼續使用 Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) 或 [Mac Mouse Fix 2 的最新版本](https://redirect.macmousefix.com/?target=mmf2-latest)。希望這能為大家提供一個好的解決方案。

*在 Claude 的出色協助下編輯。*

---

另請查看之前的版本 [**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3)。