**ℹ️ Mac Mouse Fix 2 用户须知**

随着 Mac Mouse Fix 3 的推出，应用的定价模式已更改：

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

对造成的不便我深表歉意，希望这个解决方案能让大家满意！

---

Mac Mouse Fix **3.0.4** 改进了隐私保护、效率和可靠性。\
它引入了新的离线许可系统，并修复了几个重要bug。

### 增强隐私保护和效率

3.0.4 引入了新的离线许可验证系统，最大限度地减少互联网连接。
这提高了隐私保护并节省了计算机系统资源。
获得许可后，应用现在可以100%离线运行！

<details>
<summary><b>点击查看更多详情</b></summary>
之前的版本在每次启动时都会在线验证许可，这可能允许第三方服务器（GitHub和Gumroad）存储连接日志。新系统消除了不必要的连接 – 在初始许可激活后，只有在本地许可数据损坏时才会连接互联网。
<br><br>
虽然我个人从未记录任何用户行为，但之前的系统理论上允许第三方服务器记录IP地址和连接时间。Gumroad还可以记录你的许可密钥，并可能将其与你购买Mac Mouse Fix时他们记录的任何个人信息关联起来。
<br><br>
在构建原始许可系统时我没有考虑到这些细微的隐私问题，但现在，Mac Mouse Fix已经尽可能地保护隐私且减少网络连接！
<br><br>
另请参阅<a href=https://gumroad.com/privacy>Gumroad的隐私政策</a>和我的这条<a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>GitHub评论</a>。

</details>

### Bug修复

- 修复了使用"点击并拖动"进行"空间和调度中心"操作时，macOS有时会卡住的bug。
- 修复了使用Mac Mouse Fix的"点击"操作（如"调度中心"）时，系统设置中的键盘快捷键有时会被删除的bug。
- 修复了[一个bug](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22)，该bug导致已购买应用的用户有时会收到"免费试用已结束"的通知，且应用停止工作。
    - 如果你遇到了这个bug，我真诚地道歉。你可以在[这里申请退款](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund)。
- 使"激活许可"界面的文本框无法输入空格和换行符。
    - 这是一个常见的困扰点，因为从Gumroad的邮件中复制许可密钥时很容易意外选中隐藏的换行符。
- 改进了应用检索主窗口的方式，这可能修复了"激活许可"界面有时无法显示的bug。

### 停止（非官方）支持 macOS 10.14 Mojave

Mac Mouse Fix 3 官方支持 macOS 11 Big Sur 及更高版本。然而，对于愿意接受一些故障和图形问题的用户，Mac Mouse Fix 3.0.3 及更早版本仍可在 macOS 10.14.4 Mojave 上使用。

Mac Mouse Fix 3.0.4 停止了该支持，**现在需要 macOS 10.15 Catalina**。\
对此造成的不便我深表歉意。这个改变让我能够使用现代Swift特性实现改进的许可系统。Mojave用户可以继续使用 Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) 或 [Mac Mouse Fix 2的最新版本](https://redirect.macmousefix.com/?target=mmf2-latest)。希望这是一个让所有人都满意的解决方案。

### 底层改进

- 实现了新的"MFDataClass"系统，在保持Mac Mouse Fix配置文件可读性和可编辑性的同时，实现更强大的数据建模。
- 建立了支持除Gumroad之外其他支付平台的功能。因此将来可能会有本地化结算，应用也可以在不同国家销售。
- 改进了日志记录，使我能够为遇到难以重现的bug的用户创建更有效的"调试版本"。
- 许多其他小改进和清理工作。

*在Claude的出色协助下编辑。*

---

另请查看之前的版本[**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3)。