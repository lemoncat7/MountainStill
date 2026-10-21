# Desktop mode / 桌面模式

## 使用与恢复

游戏默认以 1200 × 320 的桌面窄条启动；按 Esc / F8 恢复为 1200 × 400 的普通窗口。正常屏幕上的最小宽度为 1000，最小高度为 320。若可用屏幕更小，尺寸会缩小到可见区域，以保留恢复入口。

- 新存档默认进入桌面模式；首次窗口会放到当前屏幕可用区域底部，留出 12 像素边距，不主动覆盖系统任务栏或 Dock。可在右上小印的设置中切换，或按 F2 在窄条和普通窗口之间切换。后续启动会记住窗口模式、宽度和位置，并把超出当前屏幕的位置恢复到可见区域。
- 右上小印提供设置与恢复入口；顶部安全区可用于拖动，窗口宽度在设置中调整。
- 未暂停时约每十秒自动保存。暂停会即时保存，但暂停期间再次移动窗口或修改音量后，请点「保存」或「保存离山」，让新位置与设置写入本地档。
- 点击右上小印中的恢复操作，或在窗口有焦点时按 **Esc / F8**，会关闭透明、置顶、穿透，恢复带标题栏的普通窗口。
- 快捷键只在本游戏有焦点时生效；它不是系统全局快捷键。若失去焦点，先点击右上小印、场景入口或通过系统切换器选中游戏。
- 不会申请管理员权限、系统级输入监听、桌面文件访问或跨应用控制。

## 平台差异

背景透明依赖 GPU、渲染后端和桌面合成器。此项目先检测可用性，失败时保留正常背景。原生窗口标志只影响本游戏。

新存档默认尝试透明天空，已有存档保留用户的透明偏好。透明时采用 `sanctuary-diorama.png` 的实际 alpha；普通窗口或透明不可用时采用 `sanctuary-warm.png` 的完整暖色背景。

- **Windows：**支持尝试置顶和透明。此版本禁用景观区穿透：Godot 的区域穿透会同时停止绘制被穿透部分，会让景观场景消失。
- **macOS：**提供部分空白区域穿透，同时保留右上小印、顶部安全区和场景入口点击。Dock、Spaces、全屏应用和窗口管理器会影响最终显示及叠放。
- **Linux X11：**提供区域穿透；置顶和透明效果取决于窗口管理器与合成器。
- **Linux Wayland：**区域穿透保持关闭。窗口位置、置顶可能由合成器控制；可拖动顶部安全区安排位置。
- **无显示环境：**安全跳过原生窗口操作；测试通过不代表图形桌面行为已验证。

Godot 的区域穿透接口定义的是“接受点击的区域”，空数组表示恢复整个窗口可点。Windows 会隐藏区域外的绘制内容；macOS/X11 保持绘制。官方实现不包含 Wayland。[Godot 4.6 DisplayServer 文档](https://docs.godotengine.org/en/4.6/classes/class_displayserver.html#class-displayserver-method-window-set-mouse-passthrough)

## 安全的穿透设计

点击穿透默认关闭，仅在桌面窄条中由用户主动开启。右上小印所在的顶部全宽安全区始终接收鼠标输入，最少保留 50 原生像素；人物、药圃、丹炉、石刻等实际场景入口也保留输入。打开需要操作的抽屉或弹窗前，主界面应暂时关闭穿透。

场景入口的矩形从顶部安全区向下连接，组成一个不自相交的梳形多边形。横向范围重叠或相接时，合并后保留最大的深度；因此入口上方的少量空白也会接收点击，这是为保证入口始终可用而作出的保守选择，并非逐像素 alpha 命中检测。其余多边形外区域才尝试穿透。

坐标会按视口变换转换成窗口原生像素并向外取整、裁剪；安全区缺失、非有限数值或其他无效测量会自动关闭穿透。代码从不启用 `Window.mouse_passthrough = true`。恢复时清空区域，重新接收所有输入；Godot 的空数组表示“整个窗口接收输入”，不是“整个窗口穿透”。

## 真正的透明天空

原生窗口透明和画面 alpha 是两件事。需要 `display/window/per_pixel_transparency/allowed=true`、`Window.transparent=true`、继承自视口的 `Window.transparent_bg=true` 三者配合；帮助类在支持的桌面模式下设置后两项，不支持时关闭实际透明标志并保留可读的普通背景。[Window.transparent](https://docs.godotengine.org/en/4.6/classes/class_window.html#class-window-property-transparent) · [Viewport.transparent_bg](https://docs.godotengine.org/en/4.6/classes/class_viewport.html#class-viewport-property-transparent-bg)

主场景必须使用带真实 alpha 的景观图，让天空保持无绘制；不要在图后铺纸色矩形、底板或全屏不透明 `ColorRect`，也不要把整张图调低透明度来冒充镂空。用 `Color.WHITE` 绘制图像可保留素材自身的 alpha，山石和人物仍保持正常不透明。暂停遮罩、纸页、阴影等也不能无意覆盖整块透明天空。透明布局判断应读 `desktop.transparent_enabled` 的实际结果，而不是仅看用户保存的偏好。

暂停停止数值模拟和药力计时，不会封锁界面。书页展开/合上以及独立人物特写的淡入淡出仍可发生；不要把暂停描述为所有绘制动画和 UI 完全停止。

可将项目默认清屏色显式设为 `Color(0, 0, 0, 0)`；只修改清屏色的 alpha 并不能替代窗口与视口透明标志。普通窗口和不支持透明时，由主界面绘制正常纸色背景。[默认清屏色设置](https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html#class-projectsettings-property-rendering-environment-defaults-default-clear-color)

## 开发集成

`scripts/desktop_mode.gd` 是 `RefCounted` 类 `DesktopMode`：

```gdscript
var desktop := DesktopMode.new()
desktop.attach(get_window())
desktop.update_passthrough(recovery_seal.get_global_rect(), [
    character_rect, herbs_rect, furnace_rect, stone_rect
])
desktop.set_strip(true)
desktop.set_top(true)
var applied := desktop.set_transparent(true)
desktop.set_passthrough(true)
desktop.set_width(1200)
print(desktop.status())
# On an explicit top safety-band drag gesture:
desktop.begin_drag()
# Recovery:
desktop.safe_restore()
```

API 为 `update_passthrough(safe_rect: Rect2, interactive_rects: Array = [])`，兼容旧的单矩形调用。每次小印、场景入口或窗口布局改变后更新，尤其是人物移动、缩放和纸页开关后。全部输入都是根视口坐标中的实际点击矩形；帮助类复制矩形数组，避免调用方后续修改影响保护范围。

`desired_top`、`desired_transparent`、`desired_passthrough` 是用户偏好；普通窗口中勾选透明或穿透会保留偏好，进入小窗再尝试应用。读取 `strip_enabled`、`top_enabled`、`transparent_enabled`、`passthrough_enabled` 获得实际状态；被拒绝的请求必须显示提示，不能被描述为已生效。主界面负责 Esc/F8 的恢复与 UI 状态同步。场景销毁前调用 `dispose()`，释放窗口信号连接和测量数据；窗口退出场景树时也会自动清理。

## 构建与分发

导出使用官方 Godot **4.6.3.stable** 模板。构建环境从 [Godot 官方发布](https://github.com/godotengine/godot-builds/releases/tag/4.6.3-stable) 下载模板，并用该发布的 SHA-512 清单核验。

- Windows 输出 x86_64 可执行文件，项目包嵌入其中；未做发布者签名。
- macOS 输出 `.app` 的 ZIP，Universal 二进制包含 Intel x86_64 和 Apple Silicon arm64。采用 Godot 内置 ad-hoc 签名，无 Developer ID、无公证。不要将它描述为已通过 Gatekeeper 或商店分发审核。
- Linux 输出 x86_64 可执行文件与 tar.gz 便携包。
- 未在 Windows 或 macOS 主机执行这些构建。只有导出成功、包结构检查或 Linux 测试不能证明 Windows/macOS 的启动、透明和窗口交互已经通过。

系统警告由用户审阅；项目不修改系统安全策略、自动清除隔离属性或关闭 Gatekeeper/SmartScreen。正式对外分发前，应由持有证书的发布者签名、公证并补做目标系统测试。[官方 macOS 导出说明](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_macos.html) · [官方 Windows 导出说明](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_windows.html)

## 发布前验收清单

- 在 Windows 10/11、Apple Silicon macOS、Intel macOS 分别启动，验证中文字体、音频和存档。
- 普通窗口 ⇄ 窄条模式重复切换；宽度调整后右上小印和恢复入口仍可见。
- 移到另一块显示器、改变 DPI 或拔除显示器后，恢复操作能回到可见区域。
- 验证透明天空实际露出背后桌面，山石与人物仍清晰；不可用时提示清楚且画面可读。
- macOS/X11 开启穿透后，在梳形区域外的空白处点击应送达后方窗口；右上小印、顶部安全区及人物、药圃、丹炉、石台、小狐入口仍响应。移动人物和调整宽度后重复验证；关闭穿透后整个游戏恢复可点。
- Windows/Wayland 请求穿透时明确提示不可用，景观画面完整保留。
- 系统切换回来，点击右上小印并按 F8，确认标题栏、背景及正常输入全部恢复。
