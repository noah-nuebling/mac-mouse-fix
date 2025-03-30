Mac Mouse Fix **3.0.4 Beta 1** 改进了隐私保护、运行效率和稳定性。\
它引入了新的离线授权系统，并修复了几个重要的bug。

### 增强隐私保护和效率

- 引入新的离线授权验证系统，最大限度减少互联网连接。
- 应用程序现在只在绝对必要时才会连接互联网，保护您的隐私并减少资源使用。
- 获得授权后，应用程序在正常使用时完全离线运行。

<details>
<summary><b>详细隐私信息</b></summary>
之前的版本在每次启动时都会在线验证授权，这可能导致第三方服务器（GitHub和Gumroad）存储连接日志。新系统消除了不必要的连接 - 在初始授权激活后，只有在本地授权数据损坏时才会连接互联网。
<br><br>
虽然我个人从未记录任何用户行为，但之前的系统理论上允许第三方服务器记录IP地址和连接时间。Gumroad还可能记录您的授权密钥，并可能将其与您购买Mac Mouse Fix时他们记录的任何个人信息关联起来。
<br><br>
在构建原始授权系统时我没有考虑到这些细微的隐私问题，但现在，Mac Mouse Fix尽可能做到私密且不依赖互联网！
<br><br>
另请参阅<a href=https://gumroad.com/privacy>Gumroad的隐私政策</a>和我的这条<a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>GitHub评论</a>。

</details>

### Bug修复

- 修复了使用"点击并拖动"进行"空间和调度中心"操作时，macOS有时会卡住的bug。
- 修复了在使用Mac Mouse Fix定义的"点击"操作（如"调度中心"）时，系统设置中的键盘快捷键有时会被删除的bug。
- 修复了[一个bug](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22)，该bug导致已购买应用的用户有时会收到"免费试用期已结束"的通知，且应用停止工作。
    - 如果您遇到了这个bug，我真诚地为给您带来的不便道歉。您可以在[这里申请退款](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund)。

### 技术改进

- 实现了新的"MFDataClass"系统，实现更清晰的数据建模和人类可读的配置文件。
- 建立了对Gumroad以外的支付平台的支持。因此将来可能会有本地化的结算，应用也可能在不同国家销售！

### 停止（非官方）支持macOS 10.14 Mojave

Mac Mouse Fix 3正式支持macOS 11 Big Sur及更高版本。然而，对于愿意接受一些故障和图形问题的用户，Mac Mouse Fix 3.0.3及更早版本仍可在macOS 10.14.4 Mojave上使用。

Mac Mouse Fix 3.0.4停止了该支持，**现在需要macOS 10.15 Catalina**。\
对此给您带来的不便我深表歉意。这个改变使我能够使用现代Swift特性实现改进的授权系统。Mojave用户可以继续使用Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3)或[Mac Mouse Fix 2的最新版本](https://redirect.macmousefix.com/?target=mmf2-latest)。我希望这能为大家提供一个好的解决方案。

*在Claude的出色协助下编辑。*

---

另请查看之前的版本[**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3)。