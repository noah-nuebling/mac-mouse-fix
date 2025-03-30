另外也请查看 [3.0.0 Beta 4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-4) 中引入的**重要更新**！

---

**3.0.0 Beta 5** 恢复了在 macOS 13 Ventura 下对某些**鼠标**的**兼容性**，并**修复**了许多应用中的**滚动问题**。
此外还包含了一些小修复和体验改进。

以下是**所有更新**：

### 鼠标

- 修复了在终端和其他应用中的滚动问题！详见 GitHub Issue [#413](https://github.com/noah-nuebling/mac-mouse-fix/issues/413)。
- 通过放弃使用不稳定的 Apple API 转而采用底层技术，修复了在 macOS 13 Ventura 下与某些鼠标的不兼容问题。希望这不会带来新的问题 - 如果有问题请告诉我！特别感谢 Maria 和 GitHub 用户 [samiulhsnt](https://github.com/samiulhsnt) 帮助解决这个问题！更多信息请参见 GitHub Issue [#424](https://github.com/noah-nuebling/mac-mouse-fix/issues/424)。
- 点击鼠标按钮 1 或 2 时不再占用 CPU。点击其他按钮时的 CPU 使用率也略有降低。
    - 这是一个"调试版本"，所以在这个测试版中点击按钮时的 CPU 使用率可能比正式版本高约 10 倍
- 用于 Mac Mouse Fix "平滑滚动"和"滚动与导航"功能的触控板滚动模拟现在更加准确。这可能会在某些情况下带来更好的体验。

### 界面

- 从旧版本 Mac Mouse Fix 更新后自动修复辅助功能访问权限问题。采用了 [2.2.2 版本说明](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.2) 中描述的更改。
- 在"授予辅助功能访问权限"界面添加了"取消"按钮
- 修复了安装新版本 Mac Mouse Fix 后，由于新版本连接到旧版本的"Mac Mouse Fix Helper"导致配置无法正常工作的问题。现在，Mac Mouse Fix 将不再连接到旧版本的"Mac Mouse Fix Helper"，并在适当时候自动禁用旧版本。
- 当由于系统中存在其他版本的 Mac Mouse Fix 导致无法正常启用时，为用户提供修复说明。此问题仅在 macOS Ventura 下出现。
- 优化了"授予辅助功能访问权限"界面的行为和动画
- 启用 Mac Mouse Fix 时会将其置于前台。这改善了某些情况下的界面交互，比如在系统设置 > 通用 > 登录项中启用 Mac Mouse Fix 后。
- 改进了"授予辅助功能访问权限"界面的文本
- 改进了在系统设置中禁用 Mac Mouse Fix 时尝试启用它时显示的文本
- 修复了一处德语界面文本

### 底层更新

- "Mac Mouse Fix"和内嵌的"Mac Mouse Fix Helper"的构建版本号现在已同步。这用于防止"Mac Mouse Fix"意外连接到旧版本的"Mac Mouse Fix Helper"。
- 通过删除初始配置中的缓存数据，修复了首次启动应用时许可证和试用期数据有时显示不正确的问题
- 大量清理项目结构和源代码
- 改进了调试信息

---

### 如何帮助我们

你可以通过分享你的**想法**、**问题**和**反馈**来帮助我们！

分享**想法**和**问题**的最佳地点是 [反馈助手](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report)。
提供**快速**非结构化反馈的最佳地点是 [反馈讨论](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366)。

你也可以在应用内的"**ⓘ 关于**"标签页访问这些地方。

**感谢**你帮助改进 Mac Mouse Fix！💙💛❤️