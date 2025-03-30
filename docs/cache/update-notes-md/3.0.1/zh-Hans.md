Mac Mouse Fix **3.0.1** 带来了多项错误修复和改进，以及一个**新语言**！

### 新增越南语！

Mac Mouse Fix 现已支持 🇻🇳 越南语。特别感谢 @nghlt [在 GitHub 上](https://GitHub.com/nghlt)的贡献！

### 错误修复

- Mac Mouse Fix 现在可以正常支持**快速用户切换**！
  - 快速用户切换是指在不退出第一个账户的情况下登录第二个 macOS 账户。
  - 在此更新之前，快速用户切换后滚动功能会停止工作。现在所有功能都应该正常运行了。
- 修复了首次启动 Mac Mouse Fix 时按钮标签页布局过宽的小问题。
- 改进了在快速连续添加多个动作时'+'字段的可靠性。
- 修复了由 @V-Coba 在 Issue [735](https://github.com/noah-nuebling/mac-mouse-fix/issues/735) 中报告的一个罕见崩溃问题。

### 其他改进

- 使用'平滑度：常规'设置时，**滚动感觉更灵敏**。
  - 滚动轮转动越快，动画速度现在会变得更快。这样在快速滚动时感觉更灵敏，而在慢速滚动时仍然保持平滑。

- 使**滚动速度加速**更加稳定和可预测。
- 实现了在更新到新版本 Mac Mouse Fix 时**保留设置**的机制。
  - 之前，如果设置结构发生变化，Mac Mouse Fix 会在更新到新版本后重置所有设置。现在，Mac Mouse Fix 会尝试升级设置结构并保留您的偏好。
  - 目前这仅适用于从 3.0.0 更新到 3.0.1。如果您从 3.0.0 之前的版本更新，或者从 3.0.1 降级到之前的版本，您的设置仍会被重置。
- 按钮标签页的布局现在能更好地适应不同语言的宽度。
- 改进了 [GitHub Readme](https://github.com/noah-nuebling/mac-mouse-fix#background) 和其他文档。
- 改进了本地化系统。翻译文件现在会自动清理并分析潜在问题。新的[本地化指南](https://github.com/noah-nuebling/mac-mouse-fix/discussions/731)包含了自动检测到的问题以及其他有用信息，为想要帮助翻译 Mac Mouse Fix 的人提供指导。移除了对 [BartyCrouch](https://github.com/FlineDev/BartyCrouch) 工具的依赖，该工具之前用于实现部分功能。
- 改进了多个英语和德语的界面文本。
- 大量底层清理和改进。

---

另外别忘了查看 [**3.0.0**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0) 的发布说明 - 这是 Mac Mouse Fix 迄今为止最大的更新！