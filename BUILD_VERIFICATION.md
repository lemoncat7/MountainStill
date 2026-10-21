# v1.3.8-test.1 构建与验证

日期：2026-10-21；构建环境 Linux；Godot 4.6.3 stable official（standard）。
基线：已交付 v1.3.8 源码，SHA256 `cc4eb0a0a016fccf199d609d12be8613e9ecd709134b218c40567cfe40b6a21d`。

## 发布专用改动
- Windows/macOS 导出元数据从历史 1.3.2 修正为 1.3.8；不改变游戏玩法版本。
- 补齐旧导出白名单漏掉的新脚本、嵌套攻击模组、角色模板、归一化衣装与战斗素材，以及 fallen-body-landmarks 数据。初次导出的退出码虽为 0，实际载荷启动存在缺资源错误；已重建，最终包以严格日志检查为准。
- 强化载荷审计：Script 资源即使解析失败也可能返回对象，因此新增 `can_instantiate()` 检查，并检查完整显式资源白名单。
- 清除历史生成证据与个人路径；增加中文启动说明、权利说明与 .gitignore。

## 本次重新运行
以下为 Linux 上 Godot headless 源码测试，不是 Windows/macOS 真机测试：

| 测试 | 检查数 | 失败 |
|---|---:|---:|
| 新玩家完整旅程 | 1613 | 0 |
| 默认引导旅程 | 956 | 0 |
| 实际指针交互旅程（39 个目标） | 2439 | 0 |
| 章节制作旅程 | 325 | 0 |
| 章节制作状态 | 78 | 0 |
| 章节制作 UI | 3802 | 0 |
| 桌面模式逻辑及 headless 保护 | 340 | 0 |

## 产物验证
- Windows release 导出成功；PE AMD64/x86_64 结构检查。
- macOS release 导出成功；Universal Mach-O 的 x86_64/arm64 双架构、Info.plist 1.3.8、可执行权限与 ad-hoc 签名资源存在性检查。
- 分别从 Windows EXE 内嵌载荷和 macOS PCK 在 Linux Godot 上运行资源审计及 180 帧启动冒烟；要求无 ERROR / SCRIPT ERROR。
- ZIP 完整性与 SHA256 校验。

**没有做：** Windows/macOS 原生启动、实际签名验证、Gatekeeper/SmartScreen 验收、原生图形与音频体验、最低系统版本实机测试、完整安全审计。未使用任何签名凭据。Windows 未签名；macOS 只有本地 ad-hoc 签名，无 Developer ID、无公证。
