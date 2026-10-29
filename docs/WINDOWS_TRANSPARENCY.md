# Windows 透明显示与渲染兼容（候选改动）

本轮仅调整 Windows 完整包的默认图形后端和诊断日志，不更改美术、玩法、存档、系统驱动或系统设置。尚未据用户实机日志证明黑底根因，也不承诺所有显卡均已修复。版本与正式验收状态以发布说明为准。

## 默认行为

Windows 的 Compatibility 渲染器优先使用 Godot 自带的 ANGLE（Direct3D 11）。如果初始化失败，保留引擎默认的原生 OpenGL 后备路径。macOS、Linux 的选择不变；不要额外下载非官方 DLL。

后端在进程启动时选择：这个默认策略需要新的 **Windows 完整包**，只安装游戏内容 PCK 不会切换已经运行的图形后端。已有合法 active 内容仍按原规则加载，不会为了排障删除存档或更新记录。

## 先确认独立的透明开关

- F2 切换普通窗口／桌面小窗，不等同于开启透明。
- 右上角「山」→「桌面小记」→勾选「透明街景（支持时）」。
- Esc / F8 安全恢复会主动关闭透明并回到普通窗口；之后可重新开启透明。
- 桌面小窗是无边框窗口，不是嵌入 Windows 壁纸层。Windows 景观区鼠标穿透仍未启用。

## 一次性后端对照

先正常退出所有本游戏进程，在解压后的 EXE 目录打开 PowerShell。不要清空存档，不要修改显卡驱动或系统安全设置。

显式优先 ANGLE：

```powershell
.\MountainStill.exe --rendering-driver opengl3_angle
```

显式优先原生 OpenGL，作为备用：

```powershell
.\MountainStill.exe --rendering-driver opengl3
```

这两个参数只影响本次启动；正常双击回到完整包的默认策略。它们不会禁止引擎的初始化失败后备，因此必须查看实际日志，不能仅凭命令认为已使用指定后端。

## 最小诊断

Win+R 打开：

```text
%APPDATA%\Godot\app_userdata\山隐 · Mountain Still\logs
```

查看 `godot.log` 开头的 `OpenGL API` / `Using Device`，以及 `DESKTOP DISPLAY:` 行。后者只记录操作系统名称、实际渲染后端/方法、显卡型号/厂商/API、窗口透明请求/支持/应用标志。它不记录完整命令行、用户路径、唯一设备 ID 或存档内容；相同状态不会反复输出。旧 active 内容若不含此诊断代码，仍可先使用引擎开头的后端信息。

`transparency_supported=true` 或 `window_transparent_flag=true` **不证明最终画面透明**。最终需用窗口背后的可辨识桌面／棋盘背景与截图检查，黑底不可用这些标志判为通过。Headless 日志也不能代替 Windows 桌面像素检查。

官方依据：
- https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html#class-projectsettings-property-rendering-gl-compatibility-driver-windows
- https://github.com/godotengine/godot/blob/4.6.3-stable/platform/windows/display_server_windows.cpp#L7432
- https://docs.godotengine.org/en/4.6/tutorials/editor/command_line_tutorial.html

## 完整 Windows 包内备用入口

先退出已有山隐进程，再双击与 `MountainStill.exe` 同目录的 `Start-OpenGL.cmd`。它仅为本次启动请求原生 OpenGL，不改系统、驱动、存档或更新记录；Godot 仍可能自动回退，请以日志中的实际后端为准。直接启动 EXE 默认优先 ANGLE。
