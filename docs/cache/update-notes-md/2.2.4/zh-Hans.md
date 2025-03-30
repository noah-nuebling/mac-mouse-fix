Mac Mouse Fix **2.2.4** 现已通过公证！此版本还包含一些小的错误修复和其他改进。

### **公证**

Mac Mouse Fix 2.2.4 现已通过苹果的"公证"。这意味着首次打开应用程序时，不会再出现关于 Mac Mouse Fix 可能是"恶意软件"的提示信息。

#### 背景

应用程序公证每年需要支付 100 美元。我一直反对这一做法，因为这对像 Mac Mouse Fix 这样的免费开源软件来说很不友好，而且这也感觉像是苹果在向控制和锁定 Mac（就像他们对 iPhone 或 iPad 那样）迈出的危险一步。但是缺乏公证也导致了不同的问题，包括[打开应用程序时的困难](https://github.com/noah-nuebling/mac-mouse-fix/discussions/114)，甚至出现[多种情况](https://github.com/noah-nuebling/mac-mouse-fix/issues/95)导致所有用户都无法使用该应用，直到我发布新版本。

对于 Mac Mouse Fix 3，我认为支付每年 100 美元进行公证终于是合适的，因为 Mac Mouse Fix 3 是收费的。（[了解更多](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0)）\
现在，Mac Mouse Fix 2 也获得了公证，这应该会带来更轻松和更稳定的用户体验。

### **错误修复**

- 修复了在进行屏幕录制或使用 [DisplayLink](https://www.synaptics.com/products/displaylink-graphics) 软件时，使用"点击并拖动"操作会导致光标消失然后在不同位置重新出现的问题。
- 修复了在 macOS 10.14 Mojave 和可能更早的 macOS 版本中启用 Mac Mouse Fix 时的问题。
- 改进了内存管理，可能修复了在从电脑上断开鼠标时"Mac Mouse Fix Helper"应用崩溃的问题。参见讨论 [#771](https://github.com/noah-nuebling/mac-mouse-fix/discussions/771)。

### **其他改进**

- 应用程序显示新版本 Mac Mouse Fix 可用的窗口现在支持 JavaScript。这使更新说明更美观、更易于阅读。例如，更新说明现在可以显示 [Markdown 提醒](https://github.com/orgs/community/discussions/16925) 等内容。
- 从"授予 Mac Mouse Fix Helper 辅助功能访问权限"界面中移除了指向 https://macmousefix.com/about/ 页面的链接。这是因为"关于"页面不再存在，目前已被 [GitHub Readme](https://github.com/noah-nuebling/mac-mouse-fix) 取代。
- 此版本现在包含 dSYM 文件，任何人都可以用它来解码 Mac Mouse Fix 2.2.4 的崩溃报告。
- 一些底层清理和改进。

---

另请查看之前的版本 [**2.2.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.3)。