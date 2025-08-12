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

如果你在不知道软件不再免费的情况下意外更新到了 Mac Mouse Fix 3，我很乐意为你提供[退款](https://redirect.macmousefix.com/?target=mmf-apply-for-refund)。

Mac Mouse Fix 2 的最新版本仍然**完全免费**，你可以在[这里](https://redirect.macmousefix.com/?target=mmf2-latest)下载。

对带来的不便我深表歉意，希望这个解决方案能让大家满意！

---

Mac Mouse Fix **3.0.6** 使"后退"和"前进"功能兼容更多应用。
同时修复了多个bug和问题。

### 改进的"后退"和"前进"功能

"后退"和"前进"鼠标按键映射现在**支持更多应用**，包括：

- Visual Studio Code、Cursor、VSCodium、Windsurf、Zed 和其他代码编辑器
- 许多 Apple 内置应用，如预览、备忘录、系统设置、App Store 和音乐
- Adobe Acrobat
- Zotero
- 以及更多！

此实现受到 [LinearMouse](https://github.com/linearmouse/linearmouse) 优秀的"通用后退前进"功能启发。它应该支持 LinearMouse 支持的所有应用。\
此外，它还支持一些通常需要键盘快捷键才能后退和前进的应用，如系统设置、App Store、Apple 备忘录和 Adobe Acrobat。Mac Mouse Fix 现在会检测这些应用并模拟相应的键盘快捷键。

所有在 [GitHub Issues](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aclosed%20label%3A%22Universal%20Back%20and%20Forward%22) 中曾被请求的应用现在都应该得到支持了！（感谢反馈！）\
如果你发现任何应用仍然不能工作，请在[功能请求](http://redirect.macmousefix.com/?target=mmf-feedback-feature-request)中告诉我。

### 解决"滚动间歇性停止工作"的 Bug

一些用户遇到了[问题](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20state%3Aclosed%20stops%20working%20label%3A%22Scroll%20Stops%20Working%20Intermittently%22)，即**平滑滚动随机停止工作**。

虽然我从未能重现这个问题，但我已实施了一个潜在的修复：

当设置显示同步失败时，应用现在会多次重试。\
如果重试后仍然不能工作，应用将：

- 重启"Mac Mouse Fix Helper"后台进程，这可能解决问题
- 生成崩溃报告，这可能有助于诊断 bug

我希望问题现在已经解决！如果没有，请通过[bug 报告](http://redirect.macmousefix.com/?target=mmf-feedback-bug-report)或[电子邮件](http://redirect.macmousefix.com/?target=mailto-noah)告诉我。

### 改进自由旋转滚轮行为

当你在 MX Master 鼠标（或任何其他带有自由旋转滚轮的鼠标）上让滚轮自由旋转时，Mac Mouse Fix **不再加速滚动**。

虽然这个"滚动加速"功能在普通滚轮上很有用，但在自由旋转滚轮上可能会使控制变得更困难。

**注意：**Mac Mouse Fix 目前还不完全兼容大多数罗技鼠标，包括 MX Master。我计划添加完整支持，但可能需要一段时间。在此期间，我所知道的最好的带有罗技支持的第三方驱动是 [SteerMouse](https://plentycom.jp/en/steermouse/)。

### Bug 修复

- 修复了 Mac Mouse Fix 有时会重新启用在系统设置中之前禁用的键盘快捷键的问题
- 修复了点击"激活许可证"时的崩溃
- 修复了点击"激活许可证"后立即点击"取消"时的崩溃（感谢报告，Ali！）
- 修复了在 Mac 未连接显示器时尝试使用 Mac Mouse Fix 时的崩溃
- 修复了在应用中切换标签页时的内存泄漏和其他底层问题

### 视觉增强

- 修复了在 [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5) 中引入的"关于"标签页有时太高的问题
- 中文版"免费天数已到"通知的文本不再被截断
- 修复了录制输入后"+"字段阴影的视觉故障
- 修复了"输入许可证密钥"屏幕上的占位符文本偶尔会显示在中心之外的罕见故障
- 修复了在深色/浅色模式之间切换后应用中显示的某些符号颜色错误的问题

### 其他改进

- 使一些动画（如标签页切换动画）略微更加高效
- 在"输入许可证密钥"屏幕上禁用 Touch Bar 文本补全
- 各种较小的底层改进

*在 Claude 的出色协助下编辑。*

---

另请查看之前的版本 [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5)