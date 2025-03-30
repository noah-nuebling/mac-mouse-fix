**ℹ️ Mac Mouse Fix 2 用户须知**

随着 Mac Mouse Fix 3 的推出，应用的定价模式发生了变化：

- **Mac Mouse Fix 2**\
保持完全免费，我计划继续支持。\
**跳过此更新**继续使用 Mac Mouse Fix 2。在[这里](https://redirect.macmousefix.com/?target=mmf2-latest)下载最新版本的 Mac Mouse Fix 2。
- **Mac Mouse Fix 3**\
30天免费试用，购买仅需几美元。\
**立即更新**获取 Mac Mouse Fix 3！

你可以在[新网站](https://macmousefix.com/)了解更多关于 Mac Mouse Fix 3 的定价和功能。

感谢使用 Mac Mouse Fix！:)

---

**ℹ️ Mac Mouse Fix 3 购买者须知**

如果你在不知道软件不再免费的情况下意外更新到了 Mac Mouse Fix 3，我愿意为你提供[退款](https://redirect.macmousefix.com/?target=mmf-apply-for-refund)。

Mac Mouse Fix 2 的最新版本仍然**完全免费**，你可以在[这里](https://redirect.macmousefix.com/?target=mmf2-latest)下载。

对造成的不便我深表歉意，希望这个解决方案能让大家满意！

---

Mac Mouse Fix **3.0.3** 已适配 macOS 15 Sequoia。此版本还修复了一些稳定性问题并提供了多项小改进。

### macOS 15 Sequoia 支持

应用现在可以在 macOS 15 Sequoia 上正常运行！

- 修复了在 macOS 15 Sequoia 上大多数UI动画失效的问题。现在一切都恢复正常！
- 源代码现在可以在 macOS 15 Sequoia 上编译。此前 Swift 编译器存在问题导致应用无法构建。

### 解决滚动崩溃问题

自 Mac Mouse Fix 3.0.2 以来，有[多个报告](https://github.com/noah-nuebling/mac-mouse-fix/issues/988)反映在滚动时 Mac Mouse Fix 会周期性地禁用和重新启用。这是由'Mac Mouse Fix Helper'后台应用崩溃导致的。此更新试图通过以下更改来修复这些崩溃：

- 当遇到似乎导致这些崩溃的边缘情况时，滚动机制将尝试恢复并继续运行，而不是崩溃。
- 我改变了应用处理意外状态的方式：在许多情况下，应用不会立即崩溃，而是会尝试从意外状态中恢复。
    
    - 这一改变有助于修复上述滚动崩溃问题。它可能还会预防其他崩溃。

附注：我在自己的机器上从未能重现这些崩溃，我仍然不确定具体原因，但根据收到的报告，此更新应该能防止任何崩溃。如果你仍然遇到滚动崩溃，或者你在 3.0.2 版本下遇到过崩溃，希望你能在 GitHub Issue [#988](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) 中分享你的经历和诊断数据。这将帮助我理解问题并改进 Mac Mouse Fix。谢谢！

### 解决滚动卡顿问题

在 3.0.2 中，我更改了 Mac Mouse Fix 向系统发送滚动事件的方式，试图减少可能由 Apple 的 VSync API 问题导致的滚动卡顿。

然而，经过更广泛的测试和反馈，似乎 3.0.2 中的新机制在某些场景下使滚动更流畅，但在其他场景下却更卡顿。特别是在 Firefox 中，情况明显变差。\
总的来说，新机制是否真的全面改善了滚动卡顿并不明确。而且，它可能还导致了上述滚动崩溃。

因此，我禁用了新机制，将滚动事件的 VSync 机制恢复到 Mac Mouse Fix 3.0.0 和 3.0.1 的状态。

更多信息请参见 GitHub Issue [#875](https://github.com/noah-nuebling/mac-mouse-fix/issues/875)。

### 退款

对于 3.0.1 和 3.0.2 中滚动相关的问题，我深表歉意。我大大低估了这些更改会带来的问题，而且我在解决这些问题时反应迟缓。我会尽最大努力从这次经历中吸取教训，今后对此类更改更加谨慎。我也想为受影响的用户提供退款。如果你有兴趣，请点击[这里](https://redirect.macmousefix.com/?target=mmf-apply-for-refund)。

### 更智能的更新机制

这些更改来自 Mac Mouse Fix [2.2.4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) 和 [2.2.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.5)。查看它们的发布说明了解更多细节。以下是概要：

- 新增了一个更智能的机制来决定向用户显示哪个更新。
- 从 Sparkle 1.26.0 更新框架切换到最新的 Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3)。
- 应用显示新版本 Mac Mouse Fix 可用的窗口现在支持 JavaScript，这使更新说明的格式更加美观。

### 其他改进和错误修复

- 修复了在某些情况下"关于"标签页中应用价格和相关信息显示错误的问题。
- 修复了在使用多个显示器时，平滑滚动与显示器刷新率同步机制无法正常工作的问题。
- 大量细微的底层清理和改进。

---

另请查看之前的版本 [**3.0.2**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.2)。