# v1.3.24-test.1 暂停安全归山测试版

正式历练按空格暂停后，可直接点击「归山暂歇」：只推进回程传送，回家后仍全局暂停，不先恢复战斗。重复点击不会重开传送或重复写报；试招、更新事务、关闭、树冻结、陈旧run等仍拒绝。

本轮普通 **115入口：114通过，保留encounter_balance原4474检查中的2条节奏失败**（同一剑式summit案例6.8161秒（显示6.82）低于7.0下界，未改阈值）。15个Python driver共181单测、2个真实多进程入口通过；特殊敏感度及实际产物Guard单列。

Windows实际EXE嵌入载荷、macOS实际完整PCK由Linux Godot4.6.3从空project加载：两者暂停归山376、章节目标1844、provider62、exact217及资源/容量/装备等通过。oldv10/v23双平台普通/满箧两启共16boots，新fullv24+合法activev23共4boots，真实载荷本地HTTP6阶段通过。**不是Windows/macOS本机GUI、签名、公证或公网更新链验收。**

独立Linux自然档副本GUI已覆盖960×540遗物待搜、1200×400真实fight、125%字号、空格暂停→直接归山→正常退出→重开，共4exit0。资源/RNG/进度保持暂停；fight仅新增一条retreat，原12主备档及70runtime不变。保留环境音频ERR_CANT_OPEN→Dummy警告，不称全日志clean，也不是六章自然全通。

保持schema4、Bootstrap ABI1及原更新选择：新fullv24若已有合法activev23，仍运行旧gameplay和旧暂停归山交互；实际内容更新后才得到修复。State/战斗公式/奖励/美术未改。既有33.3ms CPU门槛未关闭，无Windows代码签名、无Apple Developer ID/公证，仍为测试版，不称正式版或性能改善。不要关闭系统防护。

目标包：`MountainStill-v1.3.24-test.1-Windows-x86_64.zip`、`MountainStill-v1.3.24-test.1-macOS-Universal.zip`。详见 `docs/PAUSED-SAFE-RETREAT-v1.3.24.md`。本报告记录本地构建；发布/公共下载/原生CI后验另行证明。


## 冻结与测试边界

- 最新main `67364bdbdcf4c0224ae5b40f0697fa1725057a72`的58tools/10CI完整继承；仅native source smoke新增第13项暂停归山。376必须单条完整marker、退出0、无错误/泄漏；错数/重复/双流错误等负例通过。历史installed-package与研究pins逐字保留，不伪装成本轮原生证据。
- `cultivation.gd` SHA256 `9265d7f4325298cc0dfd9aa46096487584ef085e85eb2923b5aac218f961ca27`；`adventure_pages.gd` SHA256 `e9007b78df1026e1f4efe960789f7d02aaa2f65d8972bcc07ac5e2776a245112`；新专项 `4769d30a2dfd667563927fefda241c981790a00920fe828d466a70250bf0cfe0`。作者/独审/自然档GUI后只增文档，builder只升Service/Store内置身份与必要fixture/工具版本。
- 普通105gameplay+10updater均独立HOME/XDG串行执行；114严格通过，唯一已声明balance4474/2保留。各入口有显式成功marker；shutdown_audio原契约只有auto_accept_quit=false而无数字计数，不虚造检查数。
- Python17入口分为15driver/181单测与2真实多进程。future正例从一开始同步为1.3.24-test.2；生产Store规则未松。bootstrap故障回退故意输出的一条ERROR按原精确行单列，不忽略其他错误。
- 敏感度单列：当前earned快照、64seeds×5builds×6chapters，1920routes/1920wins、5760实际duels、17450checks/0failures。这是synthetic earned敏感度，不是自然六章全通/性能认证。
- 实际artifact Guard对新两PCK/manifest的真实size/SHA/schema4/ABI1/namespace通过。官方Godot4.6.3模板WindowsAMD64 PE1.3.24.0、macOS universal arm64+x86_64/plist1.3.24及ad-hoc结构通过；不等于有效Developer ID或公证。

## 实际载荷/升级矩阵

- 每个平台从强制零文件的empty project+实际EXE/PCK加载，`res://scripts`/scene/assets只来自载荷。直接读取6项runtime SHA；新376外置自包含仅逐字拼接冻结base helpers和child测试体，RefCounted升级桥只改SceneTree生命周期。独立审查逆变换逐字还原；不复制产品源码作为fallback。
- 四实际PCK逐成员核验：两update各380member，WinEXE内嵌和Mac完整PCK各391member；每entry的MD5/Size/SHA与已验证export-content逐成员清单相等，逐member秘密/私档/非法cache扫描通过。Godot合法runtime imported/uid元数据不等于用户编辑器缓存。
- 两actual载荷暂停376、章节1844、生命周期62/17ordered cases、exact217以及既有容量/装备/尸体/练习/石灵/更新限流和截止检查通过。相同376测试对公开v23 actual PCK因旧_depart参数API不兼容而parse拒绝，只证oracle拒绝、不是行为负对照。另用两版共有API的8check真实fight/双暂停/按钮信号探针，同一scriptSHA对新Win/Mac均8/0，对旧v23Mac因禁用/未入回程/未归家三项断言失败，且没有Parse/ScriptError；battle resources严格字典相等。两层分开，不把预期控制失败混作新包失败。
- oldv10/v23×Win/Mac×普通/满箧待领×两启=16boots：挂新PCK后运行376/1844/62/217，原State/save字节不变；保留旧Bootstrap/Service/Store SHA与能力边界，未声称旧v10拥有新Service。真实更新PCK的磁盘复制过程没有用硬链代替。
- fullv24+合法activev23×Win/Mac×两启=4boots：真实新Service/Store SHA和旧cultivation/Adventure SHA同时核验，装备/战术/存档/active保留。旧暂停交互直到内容更新才改变。
- 本地实际载荷Service/backoff与限流seed/verify=6阶段，生产transport不变；测试fixture桥仅改外置preload路径，正文逐字保留。

## 尚未验收与后续阶段

Linux自然档GUI详情见 `PAUSED-SAFE-RETREAT-CANDIDATE.md`。本次为正常主档重载，不虚称坏主档备份fallback GUI；真实自然save与原图保存在独立私有证据，绝不进入公开源码或安装包。

本builder没有push/publish/dispatch。当前commit的Windows/macOS原生源码/包CI、原生GUI/DPI/音频/GPU/FPS、签名/公证、公网下载更新链与完整native升级未由本构建证明；既有最坏CPU33.3ms门槛、节奏两断言仍开放。
