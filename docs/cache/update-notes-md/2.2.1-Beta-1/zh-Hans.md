### Ventura 支持！
Mac Mouse Fix 现已完全支持 macOS 13 Ventura。
特别感谢 [@chamburr](https://github.com/chamburr) 在 GitHub Issue [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297) 中帮助实现 Ventura 支持。

### 停止支持旧版 macOS

很遗憾，在使用 macOS 13 Ventura 进行开发时，苹果只允许为 macOS 10.13 **High Sierra 及更高版本**开发。

因此，**最低支持版本**已从 10.11 El Capitan 提升至 10.13 High Sierra。

对此我深表歉意。不过下一节有一只悠闲的瓢虫可以让你心情愉悦。

### Bug 修复 🐞
- 修复了"**应用程序特定设置**"中，尝试添加没有"Bundle ID"的应用程序时导致的崩溃问题。可能解决了 GitHub Issues [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289) 和 [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241)。
- 修复了 Mac Mouse Fix 改变某些**绘图板**滚动行为的问题。参见 GitHub Issue [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249)。
- 修复了包含"A"键的**键盘快捷键**无法被记录的问题。修复了 GitHub Issue [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275)。
- 修复了使用非标准键盘布局时某些按键**重映射**无法正常工作的问题。
- **其他**小修复和视觉改进。