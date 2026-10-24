# v1.3.24-test.1 暂停安全归山测试版

正式历练按空格暂停后，可直接点击「归山暂歇」：只推进回程传送，回家后仍全局暂停，不先恢复战斗。重复点击不会重开传送或重复写报；试招、更新事务、关闭、树冻结、陈旧run等仍拒绝。

本轮普通 **115入口：114通过，保留encounter_balance原4474检查中的2条节奏失败**（同一剑式summit案例6.8161秒（显示6.82）低于7.0下界，未改阈值）。15个Python driver共181单测、2个真实多进程入口通过；特殊敏感度及实际产物Guard单列。

Windows实际EXE嵌入载荷、macOS实际完整PCK由Linux Godot4.6.3从空project加载：两者暂停归山376、章节目标1844、provider62、exact217及资源/容量/装备等通过。oldv10/v23双平台普通/满箧两启共16boots，新fullv24+合法activev23共4boots，真实载荷本地HTTP6阶段通过。**不是Windows/macOS本机GUI、签名、公证或公网更新链验收。**

独立Linux自然档副本GUI已覆盖960×540遗物待搜、1200×400真实fight、125%字号、空格暂停→直接归山→正常退出→重开，共4exit0。资源/RNG/进度保持暂停；fight仅新增一条retreat，原12主备档及70runtime不变。保留环境音频ERR_CANT_OPEN→Dummy警告，不称全日志clean，也不是六章自然全通。

保持schema4、Bootstrap ABI1及原更新选择：新fullv24若已有合法activev23，仍运行旧gameplay和旧暂停归山交互；实际内容更新后才得到修复。State/战斗公式/奖励/美术未改。既有33.3ms CPU门槛未关闭，无Windows代码签名、无Apple Developer ID/公证，仍为测试版，不称正式版或性能改善。不要关闭系统防护。

目标包：`MountainStill-v1.3.24-test.1-Windows-x86_64.zip`、`MountainStill-v1.3.24-test.1-macOS-Universal.zip`。详见 `docs/PAUSED-SAFE-RETREAT-v1.3.24.md`。本报告记录本地构建；发布/公共下载/原生CI后验另行证明。

---
## 以下为历史轮次记录，不是 v24 验收结果

# v1.3.23-test.1 动态章节目标测试版

已通章重读现在显示真实后续目标；在途/暂停、遗物、机缘和首通待领仍优先。达到炼气中期后重读青竹关，不再重复要求同一突破。显示复用 State 真实门槛，不自动跳章、启程、领奖或改存档/战斗规则。

本轮普通回归 **114入口：113通过，保留 encounter_balance 原4474检查中的2条节奏失败**（同一剑式summit案例6.82秒低于7.0下界，阈值未改）。另15个Python driver共179单测及2个真实多进程入口通过；特殊敏感度与产物Guard单列，详见本轮报告。

Windows实际EXE嵌入载荷和macOS实际PCK均由Linux Godot4.6.3从空project加载；章节目标1844、provider62、exact217等检查通过。旧v10/v22双平台升级共16个启动case最终通过，新fullv23保留activev22共4次启动，本地实际载荷HTTP共6阶段通过。矩阵初次有1个进程被外部终止exit -9；保留原日志和合成状态、清理已验证可恢复副本后，以全新fixture串行重测通过，未确认OOM根因。**这些不等于Windows/macOS本机GUI、签名、公证或公网更新链验收。**

真实自然档副本的Linux GUI验证了960×540和1200×400、125%字号、暂停优先、取消/确认放下、正文/tooltip一致和本章敌情返回，正常exit0；不是六章自然全通或目标系统GUI。原自然存档未修改。

保持save schema4、Bootstrap ABI1与更新选择策略：新完整包如已有合法active v22，仍运行旧gameplay；实际更新内容后才得到新文案。没有混入bundle本地安装实验或微优化。现有33.3ms CPU正式门槛未解决；仍无Windows代码签名、无Apple Developer ID/公证，不能称正式版或性能改善。

目标包：`MountainStill-v1.3.23-test.1-Windows-x86_64.zip`、`MountainStill-v1.3.23-test.1-macOS-Universal.zip`。不要关闭系统防护绕过提示。详见 `docs/CHAPTER-GUIDANCE-v1.3.23.md`。此包记录本地构建验收；发布/公共下载/原生CI另由发布阶段证明。

---
## 以下为历史轮次记录，不是 v23 验收结果

# v1.3.22-test.1 provider 生命周期边界测试候选

本轮只修复精确规划可信性检查的一处异常 provider 生命周期边界：传入已经 `free()` 的对象时，先以 `typeof` 检查类型，再短路检查对象有效性，避免 Godot 4.6.3 在 `is Object` 上报脚本错误。保持原来的完整几何回退，不改剪枝策略、战斗算法、数值、美术、存档 schema4、Bootstrap ABI1 或更新命名空间；无 native 扩展。

这不是“普通玩家崩溃已修复”的结论：尚未证明正常 RefCounted 玩家模块会在这里被释放。旧日志也表明引擎可能一面报 SCRIPT ERROR，一面退出0；因此本轮专项必须同时检查完整用例、结果、退出码与 stdout/stderr，不能仅凭零断言失败放行。源码与实际Windows/macOS载荷的新专项62项、既有专项217项均严格通过，独立集成审查与Linux两场短GUI通过。最终源码113入口112通过，仅保留原两条节奏断言失败；旧v10/v21安装挂新PCK及保留合法active v21的兼容检查完成。载荷测试由Linux执行，不冒充目标系统原生GUI。验证细节与边界见 `docs/PROVIDER-LIFECYCLE-v1.3.22.md`、`BUILD_VERIFICATION.md`；公共发布/下载链由发布阶段另验。

本轮不解决 v21 徒手峰值回退或 33.3ms 性能预算。既有三原生平台固定 v20/v21 CPU 实测中，扇峰改善，但徒手最坏峰均回退；所有场景仍未达该预算。这是 headless 源码 CPU 诊断，不是 v22 包、GPU/FPS 或普遍用户硬件承诺。详见 `docs/NATIVE-CPU-v20-v21-FINAL-REPORT.md`。

已有安装只加载新 v22 PCK 即可得到这一游戏代码修复；不要求为该单行变更重装受保护更新服务。反之，完整安装 v22 若保留合法 active v21，按既有内容选择策略仍运行 v21 游戏代码，也仍保留其 provider 边界；不能把覆盖安装宣传为无条件切换到已修复内容。

目标包名：`MountainStill-v1.3.22-test.1-Windows-x86_64.zip`、`MountainStill-v1.3.22-test.1-macOS-Universal.zip`。仍为测试版，无 Windows 代码签名和 Apple Developer ID/公证；不要关闭系统防护绕过提示。

---
## 历史 v21 及更早记录（不代表 v22 重跑）

# v1.3.21-test.1 精确规划剪枝测试候选

本轮仅引入纯 GDScript 精确规划剪枝，不新增玩法或原生扩展依赖。内置可信规划调用跳过数学上不可能改善当前最优解的昂贵计算；公共 API 默认与自定义 provider 保留原完整路径。存档 schema4、Bootstrap ABI1 与更新命名空间不变。

本轮源码回归 112 入口中 111 个 exit0，仅保留 encounter_balance 的 4474 检查中 2 条既有节奏断言失败，原门槛未改。独立专项及实际 Windows/macOS 载荷的精确规划专项均为 217 检查零失败；Linux GUI 三武器、暂停/重试/Esc/原章返回、两种窗口与 UI 125% 已完成定性回归。实际两平台载荷、旧 v10/v20 安装升级和新完整包保留 active v20 的检查通过。这里的载荷检查由 Linux Godot 执行，不是本版 Windows/macOS 原生运行或 GUI 验收。

研究云坡扇最坏 CPU tick 约106–118ms→54–56ms，其他两场景未证明稳定峰值收益；p95 观察到约+0.225–0.237ms（5.6–7.9%），总耗时中位数只小降。最坏33.3ms正式门槛仍未通过，不能称全面提速、零回退或 GPU/FPS 通过。本轮没有重跑长时敏感度/压力性能套件，也不预称远端发布或公共更新链已验证。

测试版，不是正式版；本轮结果与限制见 `BUILD_VERIFICATION.md`、`docs/EXACT-PLANNER-v1.3.21.md`。本版完整包名为 `MountainStill-v1.3.21-test.1-Windows-x86_64.zip` 与 `MountainStill-v1.3.21-test.1-macOS-Universal.zip`。仍无 Windows 代码签名及 Apple Developer ID/公证；不要关闭系统防护绕过安全提示。

以下为历史记录，不代表本轮重跑结果。

---
> **v1.3.20-test.1 测试候选**：试招结果显示真实霜滞起手与中断动作，并说明两项可重叠、中断含收势。仅临时只读统计，不改战斗决策、正式战报或存档。独立审查、Linux GUI、实际两平台载荷与旧包升级检查已完成；完整回归111入口110通过，仅保留已解释的两条既有节奏断言失败，仍非正式版。详见 [本轮说明](docs/PRACTICE-CONTROL-v1.3.20.md)。下方旧轮记录不代表v20验证结果。

> **v1.3.19-test.1 测试候选**：历练页直接查看本章敌情、自愿试招并返回原章；只读导航，不改变未完行程。独立审查、Linux GUI与实际载荷/旧包升级检查已完成；完整回归保留既有两条节奏断言失败，仍非正式版。详见 [本轮说明](docs/CHAPTER-PRACTICE-v1.3.19.md)。下文旧轮记录不代表v19验证结果。

> **v1.3.18-test.1 增量**：修复 GitHub 限流截止前提前唤醒导致提示约一秒延迟；按实际剩余毫秒重排，暂停/游戏速度不延长等待。仅完整包更新安装内服务，已有 v16/v17 无需为此每版重装。详见 [本轮说明](docs/RATE-DEADLINE-v1.3.18.md)。以下旧轮记录保留为历史，不代表本轮已重新验证。

# v1.3.17-test.1 · 石灵首领分段收拳

- 仅石灵首领新增一张半收拳、半收步姿态，攻击后先收至中段，再进入已有胸前收势与待机，保留所有旧 PNG。
- 绘制和接触使用同一姿态/变换；未改动作基础时长参数、伤害公式、RNG实现、普通石灵或其他家族。新轮廓可改变追击前摇与实际战斗时序/结果，不声称全事件不变。
- 原画、透明桌面、字体、统一比例、存档 schema4、更新 ABI1 与 v16 限流说明继续保留。
- 旧安装 PCK 不替换内置更新器；需要 v16 限流退避保护请用完整 Windows/macOS 包。

测试版，不是第一正式版，也不是连续骨骼动画。头抬高仍偏早；已知两条 summit 剑式节奏诊断与最坏性能预算问题未解决。实际验证/未验证边界见 BUILD_VERIFICATION.md；只有全部发布门槛通过后才公开此候选。
