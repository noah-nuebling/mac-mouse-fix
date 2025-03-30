Mac Mouse Fix **2.2.1** 现已完全**支持 macOS Ventura**，并带来其他更新。

### Ventura 支持！
Mac Mouse Fix 现在完全支持 macOS 13 Ventura，并提供原生体验。
特别感谢 [@chamburr](https://github.com/chamburr) 在 GitHub Issue [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297) 中帮助实现 Ventura 支持。

更新包括：

- 更新了授予辅助功能访问权限的界面，以适配新的 Ventura 系统设置
- Mac Mouse Fix 将在 Ventura 的新**系统设置 > 登录项**菜单中正确显示
- Mac Mouse Fix 将在**系统设置 > 登录项**中被禁用时正确响应

### 停止支持旧版 macOS

很遗憾，在 macOS 13 Ventura 环境下开发时，Apple 仅允许为 macOS 10.13 **High Sierra 及更新版本**开发应用。

因此，**最低支持版本**已从 10.11 El Capitan 提升至 10.13 High Sierra。

### Bug 修复

- 修复了 Mac Mouse Fix 改变某些**绘图板**滚动行为的问题。详见 GitHub Issue [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249)。
- 修复了无法录制包含 'A' 键的**键盘快捷键**的问题。修复 GitHub Issue [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275)。
- 修复了使用非标准键盘布局时某些**按键重映射**无法正常工作的问题。
- 修复了在"**应用程序特定设置**"中尝试添加没有"Bundle ID"的应用时崩溃的问题。可能有助于解决 GitHub Issue [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289)。
- 修复了在"**应用程序特定设置**"中尝试添加没有名称的应用时崩溃的问题。解决 GitHub Issue [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241)。特别感谢 [jeongtae](https://github.com/jeongtae) 在查找问题原因时提供的宝贵帮助！
- 其他小bug修复和底层改进。