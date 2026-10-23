# v1.3.10-test.1 窗口与场景适配验证

2026-10-21，Linux，Godot 4.6.3 stable official standard。原 v1.3.9-test.1 发布与源目录保持不变。下面区分源码行为、真实 Linux 图形界面、导出载荷和目标系统原生验收；历史更新器验证另见 `docs/UPDATER_VERIFICATION.md`，不冒充本轮重跑。

## 源码与行为

- 默认普通窗口目标 1440×720、界面/字号 150%；按显示缩放、可用桌面空间与最小逻辑画幅限制。普通窗口与桌面条保存独立几何信息，保留旧存档迁移。
- 世界画幅固定 1040×280、底部居中，窗口变化裁切/扩展视野而不拉伸人物与场景。七张原始透明 PNG 直接作为运行依赖，原图字节未改。
- 传送 shader 移除重复纹理相乘；不改原画、战斗或存档 schema 4。更新 bootstrap ABI 1、pack guard 与信任策略未改。
- 最终源码检查：布局 475、场景 framing 961、原生几何约束 130、桌面模式 340、传送 alpha 27，均 0 失败。比例原画修订后完整六路线 2169 与玩家旅程 1613 检查均通过。
- 版本绑定检查：更新面板 21/0；真实 localhost HTTPRequest 集成 49/0；多进程嵌套 preload 替换、下一次启动、失败更新回退/存档恢复、双实例拒绝均通过。HTTP fixture 只模拟传输，不冒充可加载 PCK。

## 真实 Linux 图形检查

本轮已实际运行 Linux 图形窗口并通过桌面交互观察，不是仅 headless 节点断言。测试发现并修复 F2 切换的窗口/字号反馈环；修复后按 F2，259 ms 的实际截图已显示完整街景。最终图形验收通过：

- Godot 4.6.3 / OpenGL llvmpipe 实际桌面：1340×720、960×790、1234×650 战斗视图中怪物/场景比例正常；合成透明区域显示桌面云景，人物与街景保持不透明。
- 手动 1234×650 → F2 桌面条 → 普通窗口，尺寸和位置恢复；原生持久化 fixture 连续四轮，在立即/1/5/20 帧及保存/场景重载后无尺寸漂移，0 失败。
- 真实 campaign-demo 离场到消散采样 8 帧未观察到黑闪；原生 GPU fixture 对照普通 shader，传送起点 RGBA 完全一致、完整消散 alpha=0，3 检查 0 失败。
- 图形战斗使用演示预设，不冒充从新存档自然推进。音频设备不存在，使用 dummy 驱动；不宣称验证声音。环境存在 vsync 不支持提示，无玩法脚本错误。

## 导出与旧安装包升级

- 冻结运行源码：`cultivation.gd` SHA256 `183669bc8e1f02b58e59da6e006c217265a966629f9d434e2c6b1466e49bca2d`；`desktop_mode.gd` SHA256 `1a9d55b8ba90534a293591e636bea5f27bebb4239a510f0139896e0beb326a9a`。导出前后核对运行源码哈希无变化。
- Windows EXE 内嵌载荷与 macOS app PCK 分别在空目录由 Linux Godot 加载，全部 328 个资源可加载/脚本可实例化，旧原型资源不存在；两者 90 帧 bootstrap 冒烟通过。
- 两个平台最终 PCK 均为 78,233,916 字节，SHA256 `ff7afa30ca389908835f12dcb54988c1c2b8db5f0ef594754ef04509b20ad65b`；生产 manifest policy、大小/hash 与 PCK namespace guard 全通过。
- **实际已发布 v1.3.9 安装载荷 → 最终新 PCK 的两条升级路径均通过**：Windows 使用旧 ZIP 中的 EXE，macOS 使用旧 app PCK；不是当前 bootstrap 配假版本。旧 Windows EXE SHA256 `bc344ba02dc8dfa7e58ec93e02b07cb99dcfa13bb0f840bf10f5833f33084130`；旧 macOS PCK SHA256 `864baf41f5e9f3520bdf2f58123c3f8a2f7867212b5ec21703c7165cb6e01071`。
- Windows PE AMD64；macOS Mach-O Universal x86_64/arm64、Info.plist 1.3.10、可执行位与 ad-hoc 签名资源结构通过。分发 ZIP CRC 与 SHA256 校验；最终分发文件以 `SHA256SUMS.txt` 为准。

构建增加 `tools/verify_export_dependencies.py`：对实际导出 ZIP 核对所有运行脚本与源文件字节、静态 preload/load 引用及导入纹理 remap。删除新 helper 与原画 PNG 的故障注入会被明确拒绝，不能仅凭导出退出码 0 放行。两个 helper 与七张源 PNG 明确列入三个导出预设。

可复现旧安装包测试：

```sh
python3 tests/update_old_payload_process.py OLD_PUBLIC_RELEASE_DIR NEW_RELEASE_DIR
```

该测试从实际 v1.3.9 Windows ZIP 提取内嵌 PCK 的 EXE、从实际 macOS ZIP 提取 app PCK，在空项目与独立用户目录中由 Linux Godot 加载。先断言旧项目版本、旧 BUILTIN_VERSION 和新 helper 不存在，再由原始 bootstrap/store 校验与挂载新 PCK；只为 Linux 测试指定平台标签，不改旧版本常量或启动脚本。升级后核对 immutable bootstrap/store 字节未变、新版本与健康提交、新默认窗口/150%设置、运行时缩放模式、七张原始纹理及等比例目标矩形。此为真实旧载荷升级测试，**不是 Windows/macOS 原生执行**。

## 分发清理与限制

源码 allowlist 保留 `.gitignore`、本页、`FIRST_TEST_README.md`、`PUBLICATION_NOTES.md`、测试/构建工具、原始素材及第三方许可证；排除缓存、导出物、运行日志、录像、截图、个人存档和凭据。静态常见令牌/私钥/个人工作区路径模式扫描不等于完整安全审计。

Windows 未做代码签名；macOS 只有 ad-hoc、无 Developer ID/公证。PE/Mach-O/Info.plist/签名资源结构检查不等于系统验签。Windows/macOS 启动、实际自动重启、声音、不同 DPI/多显示器、透明/置顶/穿透、系统权限及 Gatekeeper/SmartScreen 尚未原生实机验收。Linux 图形检查不能替代这些验收。SHA256 只核对完整性，不是独立发布者签名。

本轮只构建和本地验证，未发布、未推送、未执行发布后的整包网络下载。当前测试频道是否已能发现此版本，应以实际发布状态为准。
