Mac Mouse Fix **3.0.8** 修复了界面问题及其他内容。

### **界面问题**

- 修复了"免费使用期已结束"通知卡在屏幕角落的错误。
    - 对这个错误我很抱歉！希望没有给您带来太多困扰。感谢 [Sashpuri](https://github.com/Sashpuri) 和其他人的反馈。
- 在 macOS 26 Tahoe 上禁用了新设计。现在应用的外观和功能将与 macOS 15 Sequoia 上保持一致。
    - 这样做是因为苹果部分重新设计的界面元素还未完全就绪，导致"按钮"标签页出现一些问题。比如，"-"按钮有时无法点击。
    - 现在在 macOS 26 Tahoe 上界面可能看起来有点过时。但功能应该和之前一样完整且精致 – 我认为这对用户来说更重要。

### **界面优化**

- 禁用了 Mac Mouse Fix 主窗口中的绿色信号灯按钮。
    - 这个按钮是多余的。因为窗口无法手动调整大小，所以它实际上没有任何作用。
- 修复了在 macOS 26 Tahoe 下"按钮"标签页中某些横线颜色过深的问题。
- 修复了在 macOS 26 Tahoe 下"按钮"标签页中"无法使用主鼠标按钮"的提示信息有时会被截断的错误。
- 修复了德语界面中的一处拼写错误。感谢 GitHub 用户 [i-am-the-slime](https://github.com/i-am-the-slime)！
- 解决了在 macOS 26 Tahoe 上打开窗口时，MMF 窗口有时会短暂闪现错误尺寸的问题。

### **其他更改**

- 改进了当电脑上运行多个 Mac Mouse Fix 实例时尝试启用 Mac Mouse Fix 的行为。
    - Mac Mouse Fix 现在会更加努力地尝试禁用其他 Mac Mouse Fix 实例。
    - 这可能会改善某些之前无法启用 Mac Mouse Fix 的特殊情况。
- 底层更改和清理。

---

另外请查看上一版本 [3.0.7](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.7)。