Mac Mouse Fix **2.2.5** 版本改进了更新机制，并已为 macOS 15 Sequoia 做好准备！

### 新的 Sparkle 更新框架

Mac Mouse Fix 使用 [Sparkle](https://sparkle-project.org/) 更新框架来提供出色的更新体验。

在 2.2.5 版本中，Mac Mouse Fix 将 Sparkle 从 1.26.0 升级到最新的 [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3)，包含安全修复、本地化改进等更多内容。

### 更智能的更新机制

现在有了一个新机制来决定向用户显示哪个更新。行为变化如下：

1. 在跳过**主要**更新（如 2.2.5 -> 3.0.0）后，你仍会收到**次要**更新（如 2.2.5 -> 2.2.6）的通知。
    - 这让你能够轻松继续使用 Mac Mouse Fix 2 的同时接收更新，详见 GitHub Issue [#962](https://github.com/noah-nuebling/mac-mouse-fix/issues/962)。
2. Mac Mouse Fix 现在会显示最新主要版本的第一个版本更新，而不是显示最新版本。
    - 示例：如果你使用的是 MMF 2.2.5，而 MMF 3.4.5 是最新版本，应用现在会显示 MMF 3 的第一个版本（3.0.0），而不是最新版本（3.4.5）。这样，所有 MMF 2.2.5 用户在切换到 MMF 3 之前都能看到 MMF 3.0.0 的更新日志。
    - 说明：
        - 这样做的主要原因是，今年早些时候，许多 MMF 2 用户直接从 MMF 2 更新到 MMF 3.0.1 或 3.0.2。由于他们从未看到 3.0.0 的更新日志，他们错过了有关 MMF 2 和 MMF 3 之间定价变化的信息（MMF 3 不再完全免费）。所以当 MMF 3 突然要求付费继续使用时，一些用户感到困惑和不满，这是可以理解的。
        - 缺点：如果你只想更新到最新版本，在某些情况下现在需要更新两次。这略显低效，但通常只需要几秒钟。考虑到这使主要版本之间的变化更加透明，我认为这是一个合理的权衡。

### 支持 macOS 15 Sequoia

Mac Mouse Fix 2.2.5 将在新的 macOS 15 Sequoia 上完美运行 - 就像 2.2.4 一样。

---

另外请查看之前的版本 [**2.2.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4)。

*如果更新后启用 Mac Mouse Fix 遇到问题，请查看['启用 Mac Mouse Fix'指南](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861)。*