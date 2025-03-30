Mac Mouse Fix **2.2.5** 版本改進了更新機制，並已準備好支援 macOS 15 Sequoia！

### 全新的 Sparkle 更新框架

Mac Mouse Fix 使用 [Sparkle](https://sparkle-project.org/) 更新框架來提供優質的更新體驗。

在 2.2.5 版本中，Mac Mouse Fix 從 Sparkle 1.26.0 升級至最新的 [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3)，包含安全性修復、本地化改進等更多功能。

### 更智能的更新機制

現在有一個新機制來決定向用戶顯示哪些更新。行為變更如下：

1. 在跳過**主要**更新（如 2.2.5 -> 3.0.0）後，你仍會收到**次要**更新（如 2.2.5 -> 2.2.6）的通知。
    - 這讓你可以輕鬆地繼續使用 Mac Mouse Fix 2 的同時接收更新，正如 GitHub Issue [#962](https://github.com/noah-nuebling/mac-mouse-fix/issues/962) 中討論的那樣。
2. Mac Mouse Fix 現在會顯示最新主要版本的首個版本更新，而不是最新版本。
    - 例如：如果你使用的是 MMF 2.2.5，而 MMF 3.4.5 是最新版本，應用程式現在會顯示 MMF 3 的首個版本（3.0.0），而不是最新版本（3.4.5）。這樣，所有 MMF 2.2.5 用戶在轉到 MMF 3 之前都能看到 MMF 3.0.0 的更新日誌。
    - 討論：
        - 這樣做的主要原因是，今年早些時候，許多 MMF 2 用戶直接從 MMF 2 更新到 MMF 3.0.1 或 3.0.2。由於他們從未看到 3.0.0 的更新日誌，他們錯過了有關 MMF 2 和 MMF 3 之間價格變更的信息（MMF 3 不再完全免費）。所以當 MMF 3 突然要求付費才能繼續使用時，一些用戶感到困惑和不滿，這是可以理解的。
        - 缺點：如果你只想更新到最新版本，在某些情況下現在需要更新兩次。這略顯效率低下，但通常只需要幾秒鐘。考慮到這使主要版本之間的變更更加透明，我認為這是一個合理的權衡。

### 支援 macOS 15 Sequoia

Mac Mouse Fix 2.2.5 將在新的 macOS 15 Sequoia 上運行良好 - 就像 2.2.4 一樣。

---

另外請查看之前的版本 [**2.2.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4)。

*如果你在更新後無法啟用 Mac Mouse Fix，請查看['啟用 Mac Mouse Fix' 指南](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861)。*