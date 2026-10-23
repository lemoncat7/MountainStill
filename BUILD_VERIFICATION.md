# v1.3.22-test.1 构建与兼容验证

## 范围与已确定证据
- 基于当前完整 main `7078d5f1d4daec178698a6335934bfd63d7227ac`，继承1257项git文件；55项native workflow/doc/test/tool原字节和历史pins保持。`package_source.py`明确补齐漏掉的7项CPU诊断文件，不把它们算作v22原生运行证明。
- 产品行为只有 Geometry `_fit_pruning_safe` 一行 `typeof(provider)!=TYPE_OBJECT`；保持 `is_instance_valid` 的短路和 `get_script` 次序。Geometry SHA256 `3abcf94892b98f8b4ffc406de52093e9bf7d45b4b23ca4f76ebb38dfc3f7ce30`。Duel、剪枝算法、浮点顺序、数值、美术、save schema4、Bootstrap ABI1均不改。
- 原v21在新自包含专项中打印62 checks/0 failures且exit0，stderr却有9条SCRIPT ERROR；严格gate拒绝，原日志留在 `docs/qa/provider-lifecycle-v1322/baseline-v21-*.txt`。旧零失败/exit0不是这个生命周期边界正确的证据。
- 作者独立局部证据为66个三方进程记录、109验证项、27候选进程clean及5个negative oracle；三场景cold/warm、480 tick声明schema内完整trace与v21相等。来源报告保留于本轮QA目录，不替代完整集成或包验收。

## 已完成：源码集成与独立审查
- 官方Godot4.6.3规范editor import exit0且无SCRIPT ERROR/Parse Error/ERROR；新自包含专项17用例/62检查零失败、旧精确规划专项217检查零失败，均exit0且stdout/stderr无错误。作者与独立集成审查分别重跑相同两个入口通过。
- 严格driver13个单元测试通过，包含exit0伴SCRIPT ERROR等假阳性负例，并强制实际包运行使用完全空project且输出目录位于其外。自包含脚本没有外置test fixture依赖，可交实际PCK阶段执行。
- 从集成源码另新跑作者原27个模式，全部clean，各VALUE_SHA256与冻结作者候选相同；三方109验证项通过。v20/v21记录明确沿用作者保留证据，没有冒充本轮重新运行三方66个进程。
- 70 runtime/config + 5专项/driver冻结清单SHA256：`c1594174562a1ef246b5313084694ec4b24342912d6a06c9b8e53f4cb78097b2`。独审运行前后逐项核验不变；相对v21只有Geometry及project/export/Service/Store四项版本字段变化，其他65项runtime保持。
- 初次未import的诊断确因缺ctex报错，原日志保留在外部集成QA；规范import后无代码规避地重跑成功。初版driver检查数误写60后按实际62修正，修改前后证据保留，未降低测试断言或日志门槛。

## 已完成：Linux 原生 GUI 短回归
- 冻结独立副本，Godot4.6.3/Linux真实桌面，徒手960×540与扇1200×400条带、UI125%各一场；两进程正常关闭exit0，无SCRIPT ERROR/Parse Error。自然完成、暂停/继续、同敌重试、Esc或显式结束、回同敌/原章通过，根代理复核两张原始结果图。
- 70runtime+5专项前后匹配，464资产/import sidecar同字节。沿用此前自然养成终章合法装备库存fixture，通过真实API切装；不是本轮重新自然养成。完整save差异只含saved_at和正常窗口设置，资源、正式战报、阶段记录及18胜场总数不变。
- 存在VSync不支持与PulseAudio/ALSA ERR_CANT_OPEN、Dummy音频回退，不写成GUI日志全无ERROR，不声称音频通过。不是Windows/macOS原生GUI、每帧无问题、FPS/GPU、长时稳定性或真实玩家触发freed边界证明。
- 原报告见 `docs/PROVIDER-LIFECYCLE-v1.3.22-NATIVE-GUI.md`；原图、完整日志、前后测试存档保留在独立内部GUI证据包，不作为公开Source的运行时文件。

## 最终源码回归与实际包
- 最终源码113入口（包含10个更新入口）中112严格通过；唯一失败为既有 encounter_balance 的4474检查中两条summit剑式节奏断言，实测6.82秒低于原7.0秒下界。未删除、放宽门槛或把已知失败计为通过；无新增失败及SCRIPT ERROR。10更新入口串行通过，另真实localhost HTTP两进程持久限流seed/verify通过。
- 15个Python驱动文件共176单元测试通过：14个native驱动163项，加本轮严格lifecycle驱动13项。它们是驱动逻辑测试，不代表v22目标平台原生执行。
- GUI退出后≤2并行源码回归，随后串行更新、独占官方Godot4.6.3导出；本轮10构建/测试阶段均首轮exit0。Windows AMD64、macOS x86_64/arm64 universal结构、版本、执行权限、资源签名目录、manifest实际长度/SHA及生产Policy/Guard通过。结构不是Windows签名或Apple公证/原生系统验收。
- Linux Godot从完全空项目加载实际Windows EXE内嵌载荷及Mac包提取PCK，不回退到源码runtime。两平台各新专项17用例/62检查、旧专项217检查均零失败，exit0且双流严格无SCRIPT ERROR/Parse Error/ERROR。原有石灵、控场、导航、装备/容量等包专项亦由构建阶段执行，原日志留存。
- 两平台实际完整包Service各真实localhost HTTP测试及限流两进程重开，共6阶段通过。没有将localhost夹具冒充公共GitHub下载或公网更新链。
- 601项运行时/资源/config构建快照、70runtime+5专项冻结及55原native工具贯穿构建均无变化。详见 `docs/qa/provider-lifecycle-v1322/final-build-summary.json`；完整raw日志与失败证据在独立Build QA，不把早期作者“待验”改写成作者亲自完成后续阶段。

## 旧安装、存档与 active 内容边界
- 已公开v1.3.10/v1.3.21的Windows/macOS原载荷，各普通/容量场景、各两次启动，共16启挂载新v22 PCK；每次实际执行62+217专项，正式State与测试前后save hash不变，旧受保护Service hash保留。旧安装获得的是v22游戏内容，不暗示PCK替换旧Bootstrap或Service。
- 新完整v22包+合法active v21，两平台各两次启动共4启通过；继续保留旧v21游戏内容、active记录、原存档与新安装Service。**因此该active v21仍有旧provider生命周期边界；覆盖安装不等于无条件切换到修复后的游戏代码。** 没有删除更新记录、强制覆盖或改变既有选择策略。

## 封包与发布边界
最终Source归档按全部allowlist、CRC、逐成员当前源码、1257上游完整树、70/5冻结与55 native原字节核验；新增CPU7明确入包，不含cache/用户存档/私钥。最终归档SHA与七资产扫描结果留在外部Build QA，避免源码归档自引用自己的hash。

公开push/release、公共下载后hash与公网更新链由发布阶段另验；本报告不预称已发布。本轮没有重跑长期敏感度/性能压力，不将短回归、导出和Linux载荷通过写成Windows/macOS原生GUI、GPU/FPS、签名/公证或正式版性能达标。

## 不变的限制
本轮仅异常provider生命周期边界，未证正常RefCounted玩家模块会被释放，不称“普遍玩家崩溃修复”。不改变既有性能策略：三OS实测v21扇峰改善、徒手最坏峰回退，33.3ms预算仍未达标；见 `docs/NATIVE-CPU-v20-v21-FINAL-REPORT.md`。此前两条summit剑式节奏断言、长时敏感度、签名/公证等限制不被本轮修复自动关闭。

---
# 历史构建记录（不作为 v22 本轮证据）

# v1.3.21-test.1 构建与兼容验证

本轮只集成纯 GDScript 精确规划剪枝。保留候选顺序、strict-less 胜出、平局与原浮点运算；公共默认调用和自定义 provider 完整保留旧路径，只有 Duel 内部新建可信 planning samples 的两处调用显式启用。无 GDExtension、动态库或新增 native runtime 依赖；美术、存档 schema4、Bootstrap ABI1、更新命名空间不变。

## 冻结、独立审查与源码回归
- 70 项 runtime/config 冻结清单 SHA256：`7e08358b2f03a2397ca7897fdd63089fc95b24b78080f576a0b1c9e8127d8cae`。构建另绑定 601 项脚本/资源/config；导出后与冻结无差异。
- 两份研究最终实现：Geometry `22f6d2e77daa089f14eed6bd4982c89561193f42aac485201beb704464b15752`；Duel `c71e5419b10010fc2b3225e515fc8c448676475e7d0b6dce18a9398b9b5432f9`。必要九个版本文件同步，不改变 save schema 或 updater 行为。
- 作者与独立审查分别执行最终自包含专项：217 checks / 0 failures，exit0；本轮全量源回归再次通过该入口。真实 neutral early-return 32 次、finite equal-best 2 次；公共默认/false、trusted fresh/warm、自定义 provider、污染外部 samples 和 fail-open 边界按测试设计覆盖。finite tie 是公共默认路径 fixture，不冒充 trusted-path 对恶意 samples 的保证。
- 最终源码 GDScript 回归共 112 入口：102 主入口加 10 更新入口，111 个 exit0；唯一失败为既有 encounter_balance 的 4474 检查中 2 条 summit 剑式节奏断言，实测 6.82 秒低于原 7 秒下界。没有删除或放宽阈值；无新增测试失败或 SCRIPT ERROR。
- 环境重启前 61 个已终态记录保留并逐日志哈希核验，余下 41 个重新执行；中断的两份未终态日志保留，不当作通过。10 更新入口串行通过，另有源码真实 HTTP 两进程持久限流重启通过。
- 13 个 native CI 驱动 Python 文件共 149 个单元测试全部通过；这是驱动逻辑验证，不是原生平台运行。main `e367bea61f9d5d5def932bbe479932c500b6c6fe` 的 48 项 native workflow/doc/test/tool 逐字节保留；其旧 pin 仍是历史对象，不能称 v21 原生 CI。
- 本轮未重跑长时敏感度/性能压力套件，不将 112 入口扩称全部长期或正式性能门禁。

## 实际导出与发行载荷
- Godot 4.6.3 官方工具/模板导出 Windows AMD64 与 macOS x86_64/arm64 universal。结构、版本、权限、资源签名目录、manifest 长度/SHA 与生产 Policy/Guard 检查通过；结构检查不是目标操作系统启动、公证或签名可信性验收。
- Linux Godot 从空项目直接加载实际 Windows EXE 内嵌载荷与 Mac 包 PCK，不回退到源码 runtime。两平台各 336 活跃资源加载通过；新精确规划专项各 217/0。两平台已有控场 4973、导航 386、石灵契约 22851、石灵显示 3239、装备 UI 12166，以及装备状态、容量与搜尸等专项全部通过。
- 两帧石灵 retract/settle 贴图经真实 CanvasItem draw 选用，256×256 import/remap/ctex 与锚点实际载入通过；透明天空与不透明落脚地景资源检查通过。此项不取代真实 GPU GUI。
- 实际载荷 rate-limit 55 检查、deadline 19 检查各通过；两平台完整包 Service 在真实 localhost HTTP 夹具中各 67 检查通过，持久限流两进程 seed/verify 均通过。这不代表公共 GitHub 下载或外网更新链。
- 初次默认 HOME 不可写使 editor import/export 阶段 exit1、产物 Guard 启动 exit-6；日志保留。改用任务内隔离 HOME/XDG 后对应阶段成功重跑，未改产品代码、测试或门槛。最终九个阶段均 exit0，不宣称首次全绿。

## 原安装、存档与更新兼容
- 已公开 v1.3.10 与 v1.3.20 的 Windows/macOS 原包真实载荷，各普通/100 装备待领存档、各两次启动：共 16 次旧 Bootstrap 挂载最终新 PCK 通过。
- 原装备、战术、战报与货币保留；v10 仍按既有规则迁移 balanced。满行箧 pending 失败原子性、显式整理后重试、ready 尸体派生 hold、重开后亲领与不重复领奖通过；试招仍隔离资源与正式进度。
- 旧 Bootstrap 上本章敌情→试招→返回的检查保持真实 State，临时控场计数显示而不写正式战报；旧不可变 Service 保留。v10 继续提示需要完整包获得限流保护，v20 保留原保护。
- 新 v21 完整包加载合法 active v20：两平台各两次启动，共 4 次，旧游戏内容、active 记录、原存档和新安装 Service 均保留；不声称覆盖安装强制换内容或删除 active。
- 新包 Bootstrap 正常启动、marker 删除失败故障注入和新 Service 面板能力检查通过。故障注入日志有预期 ERROR，不是实际产品新失败，也不写成零 ERROR。更新 PCK 不含受保护 Bootstrap/Service/Store。

## Linux 原生 GUI：已验证范围
- 冻结候选独立副本，真实 Linux/X11 桌面、Godot 4.6.3、llvmpipe；入口 `main.tscn`。三次隔离 GUI 会话正常关闭，均 `NATIVE_EXIT=0`，无 SCRIPT ERROR。
- 真实合法装备剑、徒手、扇试招自然完成；暂停/继续、同敌重试、Esc 取消、同敌与原浏览章返回通过。960×540 与 1200×400、游戏 UI 125% 下主要布局完整；根代理复核五张原图采样未见新黑块、形变或条形结果裁切。
- 前后完整存档差异仅保存时间和窗口设置；正式资源、战报、历练和胜场不变。合法高阶输入不是本轮重新自然养成，三个场景的耗时也不是跨武器平衡性比较。
- VSync 不受驱动支持及音频回退 Dummy 日志仍存在。不证明每一帧无闪烁、音频通过、真实 GPU/FPS 改善、DPI/置顶/穿透或本版 Windows/macOS 原生 GUI。详见 `docs/EXACT-PLANNER-v1.3.21-NATIVE-GUI.md`。

## 源打包与证据边界
源码打包清单已从 14 项历史 native 工具补齐当前 main 的 48 项，不将研究 native 实验加入产品。最终 Source ZIP 必须全成员 CRC、完整 allowlist 集合、逐成员当前源码字节与 70 runtime/2 专项/48 CI hash 共同通过；不打包 HOME/XDG、缓存、日志、用户存档或凭据。最终归档 SHA 与逐成员结论随外部 Build QA 一并保存，避免源 ZIP 自引用自身 hash。

当前本轮动态结果摘要在 `docs/qa/exact-planner-v1321/final-build-summary.json`；作者、研究、独立集成及 GUI 报告保持各自时间点和覆盖边界，不将其中“当时待验”改写成作者亲自完成后续构建。

## 仍是测试版：已知缺口未关闭
研究云坡扇 worst CPU tick 约106–118ms→54–56ms，但三个候选场景 worst 仍全部超过33.3ms；p95 观察到 +0.225–0.237ms，总耗时中位数仅小降，其他场景没有稳健普遍峰值收益。共享环境 headless ABBA 不是 GUI、GPU、FPS 或跨硬件保证；不宣称全面性能提升、零回退或正式性能达标。

既有两条节奏断言失败保留。本轮未完成 Windows/macOS 原生 GUI/CPU 正式验收、长时稳定性、Windows 代码签名或 Apple Developer ID/公证。发布、远端 commit/release 和公共下载后 hash/公共更新链需发布后另验，不预称已完成。

---
# 历史构建记录（不作为 v21 本轮证据）

# v1.3.20-test.1 构建与兼容验证

本轮只在镜中试招结果补充临时控场反馈：实际霜滞影响的敌方新起手、确实中断的敌动作（包括收势）。两项可能重叠，不等于施法次数、破势总数、避免命中次数、节省秒数或普遍胜率；缺字段显示“未记录”，不冒充零。正式战斗引擎、战报、State、存档、美术均未改。

## 冻结与独立审查
- 最终70项runtime冻结SHA256 `cf2740f50c34a788462bed6a286c190d37cce64648e634c25473368e90163bca`，实际构建另绑定601项脚本/资源/config。
- 对公开v19源ZIP逐项比较，仅practice_session/practice_pages以及project/export和Service/Store版本常量变化；Bootstrap/Guard/Policy不变，ABI1、存档schema4不变。
- 新专项4973检查零失败，9组作者定向通过。独立39组27188检查零失败，v19/v20的2965事件、3840推进步轨迹、资源、RNG、旧报告及语义姿态一致；没有把单个固定种子或合成测试写成自然通关或胜率证明。
- 最终全量111个GDScript入口，110个exit0；唯一失败为既有encounter_balance的4474检查中2条节奏断言，原门槛保留。10个更新入口全通过，另真实HTTP两进程持久等待测试通过。长时敏感度/性能压力套件未在本轮重跑，不能把这111入口扩称所有长期门禁。实际发行包Guard另按最终产物执行。本轮先等GUI退出，最多2并发回归，结束后独占官方导出；没有沿用v19首轮Killed作为本轮结果。

## 实际导出与载荷
- Godot4.6.3官方工具/模板；Windows AMD64、macOS x86_64/arm64 universal结构、版本、执行权限及资源签名目录检查。该结构检查不是原生操作系统启动或公证验签。
- Linux Godot直接加载最终Windows EXE内嵌载荷与Mac包PCK，空项目、无源码运行时回退；两平台各336活跃资源、4973控场专项、386导航专项、石灵契约22851、装备UI12166以及容量/搜尸专项通过。两帧石灵纹理import/remap/ctex、256²及锚点实际加载通过。
- 两实际完整包Service本地HTTP夹具各67检查、deadline19检查及真实两进程重开通过。测试仅将fixture URL指向localhost，不作为公共GitHub下载证据。
- 生产Policy/Guard验证两平台PCK实际SHA、长度、资源命名空间通过；更新载荷不含受保护的Bootstrap/Service/Store。

## 原安装与存档兼容
- 已公开v1.3.10、v1.3.19 Windows/macOS原包真实载荷，各普通/100装备待领存档、各两次启动，共16次旧Bootstrap挂载最终新PCK。
- 原gear、战术、战报、货币保存；v10按既有规则迁移balanced。首通pending、满背包失败原子性、显式整理后重试、尸体ready派生hold、重开后亲领及不重复领奖通过。
- 旧Bootstrap上的本章敌情→返回实际点击保持完整State快照；真实试招report包含临时控场metrics版本和非负计数，UI正确显示已测计数，不写正式存档。v10仍显示需要完整包获得限流保护的说明，v19保留原Service保护。
- 新v20完整包+合法active v19，两平台各两启保持旧游戏内容与active记录、原存档和新安装Service可用；不声称覆盖安装强制切内容或删除更新记录。

## 原生Linux GUI与边界
- 最终冻结副本3个GUI进程均exit0：新控场结果、说明显示/收起、真实Esc取消与重试、敌情/原章返回、960×540和1200×400、125%字体通过。
- 新档状态是明确隔离配置，不是首启引导验收；高阶配置取合法诊断存档并经真实API装备，不是本轮自然养成。缺字段显示使用外部report适配夹具，不是自然旧档迁移。详见 docs/PRACTICE-CONTROL-v1.3.20-NATIVE-GUI.md。
- Linux X11/llvmpipe，main.tscn直入；不是Windows/macOS原生GUI、真实GPU、音频或性能验收。

## 打包范围
三ZIP逐成员CRC、组件级路径排除、所有二进制原始字节敏感模式扫描；不含cache/fontconfig/测试隔离目录/日志/用户存档/凭据，保留合法windup-isolated美术名。Godot官方模板内NUL终止TLS解析器标签仅在邻域字节精确匹配模板时例外，不是私钥。Public Source保留完整原图/技术导入脚本与14个CI文件，CI字节对应main `04d556e51d8c86ef5c02c37d146bbb143527cc9d`；旧pin不冒充v20原生CI。

仍为测试包。没有新增全局性能达标主张，既有节奏和最坏帧耗时问题未被本轮反馈UI修复。发布后公共更新链另验，不预称已经通过。

---
# 历史构建记录（不作为v20本轮证据）

# v1.3.19-test.1 构建与兼容验证

本轮是历练本章敌情 → 自愿试招 → 返回原章的只读导航闭环，不是新战斗公式、自动领奖或 native 几何实验。以下为本轮实际验证；后附 v18 及更早记录只作历史，不代表本轮覆盖。

## 冻结与源码回归
- 最终70项runtime冻结清单 SHA256 `e8eceb1d3ae821d976e106e325c62d20f528270f6362dc0674b9af9e71e353e0`；实际构建另外绑定601项脚本、资源与配置。与公开v18源ZIP比较，仅4个导航UI脚本、project/export版本以及Service/Store版本常量不同；战斗/State/贴图/Bootstrap/Guard/Policy不变。
- 最终导航源码386检查、独立补充1512检查均零失败。跨R札记/普通衣冠切换会清除旧章节返回来源；未完行程、尸体及机缘不被导航消费。
- 完整GDScript回归110入口：首轮108个exit0；既有节奏测试4474检查有2个已知失败（6.82秒低于原7秒门槛，未修改门槛）；live_loadout_guard首轮被操作系统终止exit -9，保留日志。GUI及其余测试退出后，该项单独重跑119检查零失败、exit0。因此最终109入口验证通过，保留既有节奏2断言，不宣称首轮全绿。10个更新入口全通过，另真实HTTP两进程限流重启通过。
- 首次editor导入也被系统终止Killed；环境未提供可读cgroup OOM证据，不推断根因。待GUI退出后重新执行完整官方导出并成功，未复用失败产物。

## 实际发行载荷
- Godot 4.6.3官方工具与导出模板，Windows x86_64 PE与macOS x86_64/arm64 universal结构通过；两导出67个源码文件、109条依赖完整。结构检查不等于原生操作系统运行或公证签名验证。
- Linux Godot加载实际Windows EXE内嵌载荷与实际Mac包PCK，空项目运行、无源码运行时回退。两平台均336个活跃资源加载通过，新增导航386检查、石灵契约22851检查、装备UI12166检查、容量与搜尸等专项通过。retract/settle实际纹理、import remap/ctex、256²及锚点加载通过。
- 两平台完整包真实Service本地HTTP夹具各67检查通过，限流解析与deadline19检查通过；实际两进程等待恢复/禁止重复请求通过。夹具仅重定向测试URL，不代替公共GitHub网络验收。
- 生产Policy/Guard校验两PCK实际长度、SHA、资源命名空间通过，ABI仍1、存档schema仍4。

## 原安装更新与存档
- 从已公开v1.3.10和v1.3.18 Windows/macOS原始包提取真实载荷，各平台普通/满装备待领两种合成存档、各重开两次，共16次真实旧Bootstrap挂载新PCK。gear、战术、报告和货币保留；v10旧档按既有规则迁移balanced。
- 100装备首通pending、容量失败原子性、显式整理后重试、ready尸体派生hold、保存重开及显式亲领不重复均通过。普通旧Bootstrap还实际点击本章敌情→返回原章，整个State快照不变；真实试招不写正式存档。
- v10旧Service仍无新限流能力并显示完整包提示；v18旧Service保留既有保护。PCK不会替换受保护Service。
- 新v19完整包配已有合法active v18，两平台各两次启动仍按原策略运行v18游戏内容，保留active记录/存档，新完整包Service可用；不假称覆盖安装自动清除active或强制切新内容。

## 发行边界
- 14个CI工具/配置保留来源main `6eb28d396a3d67de0410856d664632a1754537e3` 的精确字节。本轮打包验证不冒充v19原生Windows/macOS CI或GUI；原生CI需发布后针对精确资产另行确认。
- 本轮仍为测试包；没有新的全局性能达标主张。已有最坏帧耗时问题及原先节奏门槛失败未由导航改动解决。
- 当前实际包测试运行在Linux；透明桌面、真实GPU、原生Windows/macOS及真实音频不能由该载荷验证推出。

## 本轮原生Linux GUI
最终70文件冻结副本5次真实GUI运行均exit0，98张截图：新档六章/锁章、全解锁18敌动态映射、显式试招自然结果后返回原章、跨R札记/衣冠来源、比较页面残留、保留历练/残骸/机缘三种准入通过；960×540及1200×400、125%字体可用，透明天空保留、场景比例无可见拉伸。合成夹具不是自然通关。使用Linux X11/llvmpipe，main.tscn直入，不是Windows/macOS实机或Bootstrap验证。Esc取消未在本轮GUI亲测，不将自动化覆盖冒称原生验证。详细报告由独立GUI证据归档保留。

## 本轮交付审计
三ZIP使用统一组件级排除策略，逐成员CRC/路径与所有二进制原始字节敏感模式扫描；合法windup-isolated美术名保留，cache/fontconfig/测试隔离数据/日志/凭据不入包。唯一允许的PRIVATE KEY字样是与官方Godot模板邻域逐字节一致的NUL终止TLS解析器常量，不是密钥。Public Source包含本轮测试、14CI文件和美术原图/纯技术导入脚本；不含运行用户数据。

---
# 历史构建记录（不作为v19本轮证据）

# v1.3.18-test.1 构建验证

本轮仅限流到期提示Timer精度小修。601项运行时/资源/config对v17逐项比较，仅Service、Store版本、project版本、export版本4项不同；战斗、美术、UI、Bootstrap、Guard、Policy、限流解析器均不变。完整包内容优先选择仍只是发布目录之外的设计，不属于本轮代码。

## 本轮源码与独立验证
- 主实现1169文件freeze与实际构建字节匹配；Service SHA256 `9e8cdb4cc3cc83cfecf3012e74ff2b8488424f94efcb0a6c24d6efd6491878d4`。
- 定时器以实际剩余毫秒重排，忽略游戏time_scale并在暂停期间运行。7ms/1ms提前回调仍拦截请求，不提前放行、不自动请求。主源码deadline19项通过，HTTP67、Service47、Store41、Policy160、解析55及界面/代理/Guard等相关检查通过；测试夹具初次未导入字体/复用脏目录的失败记录保留，修夹具后重跑，没有降低产品保护。
- 独立审查48项与真实HTTP两进程重开通过；正常/暂停/0.1/0倍速提前150ms唤醒后仍等至截止，所观察延迟7–8ms仅该独立headless夹具，不是全局承诺。
- 独立原生Linux/XFCE llvmpipe、Dummy audio实际游戏GUI：自然42922ms、403+暂停31ms、0.1倍速19ms；注入7/1ms重排精确0.007/0.001秒、画面观察30/32ms。960×540及实际F2条带1200×400/125%、三页帮助与旧能力mock说明完整可用，正常保存退出。GUI不代替真实旧安装链；本轮GUI未复测慢下载取消或持久重启，后者由下述实际包测试补足。

## 最终实际发行载荷
- 全新导出Windows x86_64/macOS universal，67脚本/109依赖路径逐项当前。601运行时/资源/config SHA贯穿导出与封包。空项目加载实际Win EXE内载荷和Mac ZIP内PCK，无源码fallback；336活动资源、retract/settle两图256²/import remap/ctex/sole锚及各8次实际CanvasItem绘制通过。
- 两平台实际包直接执行deadline测试各19/19：Win自然/暂停/慢速延迟8/8/14ms，Mac8/14/7ms。额外实际包内Service localhost HTTP各67/0、两独立进程恢复等待/连点抑制通过，production Policy/Guard校验manifest/SHA/大小/ABI1/schema4通过。真实传输仅在外部测试fixture映射localhost，不冒充GitHub公网。
- 两平台实际包收势contract22851/0、石灵机制3239/0、奖励228/19、装备153/UI12166/cache5、容量67/693/7238、正常bootstrap与注入确认失败暂停/释放安全路径均通过。这不是重新跑全部游戏平衡矩阵，也不抹除既有两条summit节奏失败或性能预算限制。
- 旧公开v1.3.10/v1.3.17各Windows/macOS原载荷，普通存档与100装备首通待领/已搜满尸体两场景、每例两次启动，共16次mixed启动通过；原bootstrap/store及内建版本不变。gear、战术/报告、容量失败原子性、显式整理/领取、尸体hold跨保存重启及不重复领奖均通过。v10正确显示完整安装需求；v17保留其已安装限流能力，但PCK不会升级旧Service的Timer精度。
- 完整v18+既有合法v17 active PCK，两平台各两次启动通过：gameplay仍v17，active不被擅自清除，gear/战术/存档保留；实际新Service在树暂停+0.1游戏速度下13ms早醒重排、截止前拦截、到期无新增请求通过，游戏实例实测延迟30/30/31/32ms。不能宣传始终1ms或7ms响应；界面仍受帧调度影响。
- 原main `1ebc8363fb0b04ec9d3fc374d28070a93d56f025` 的8个CI文件按SHA保留，CI固定v17，不证明v18原生包已跑。最终三ZIP逐成员路径/CRC/原始字节敏感扫描、源码与601hash/CI8核对和七资产SHA清单由最终封包检查完成。

## 安装与证据边界
仅完整安装包更新受保护Service；已有v16/v17玩家无需为此提示精度每版重装。旧gameplay PCK兼容，存档目录/ABI/schema不变。没有实现sidecar/完整包优先选择。尚未声称原生Windows/macOS GUI/GPU/DPI/签名公证、全局性能或正式版稳定性通过；公网链及发布后原生CI须另有真实证据。

---
## 以下为历史v17（及其继承v16）记录，不作为v18新跑证据

# v1.3.17-test.1 测试包验证（最终行为候选B）

- 基于v16 clean源码，保留main5916171全部8个CI文件；其原生CI固定v16，不是v17实包证明。
- 美术candidate01因脚步未到中间被拒绝；candidate02经独立原生审图接入原型。行为候选A把新帧放在recovery .34-.56，新增正式85% boss≤35秒门槛失败(50/60 vs54/60)，已明确拒绝发布并归档源overlay/QA。
- 行为候选B只将同图提前到recovery .20-.34，.34-.78沿用v16 settle；没有新帧不可见段clearance，图/锚/伤害公式/RNG实现/基础时长参数不改；轮廓仍可改变动态追击前摇与实际战斗时序。正式earned4474 checks仅既有2项summit剑式失败，boss≤35秒恢复54/60。
- B真实赚取竹林首通后听泉桥三连战carry12组，剑/火/守×标准/不买可选经脉×两冒险seed，双方全过。守标准57→57、低经脉28→28；火低经脉边界余血1→15，其余34/40不变。实际HP/战气/cooldown与原9秒旅途恢复，无boss前满血注入。
- 独立B实际GUI三招手动步进通过：sweep .204 retract→.354 settle，burst .219→.359，charge .208→.358；burst全部3contact及最后hold之后才进入retract。三招无新增体量/足底/姿态骤跳，但仍离散关键帧且头抬高略早。QA夹具两次输入/命名错误已单独保留并修正后重验，不是生产失败。

## B新增验证
- final recovery contract22,851 checks/0失败，包括retract和settle两种姿态的双方死亡终态；所有旧美术PNG及CI8完整性由独立审查确认。
- 300对固定earned快照种子（3构筑×100）：双方全胜、无超时、无空挥/无接触伤害。剑平均HP28.35→28.53，火34.93→35.02，守58.82→58.54；守最低47→45、个体HP差−11..+7、平均耗时+.084s。不是自然通关样本或战斗全事件等价。
- 独占序贯ABBA窄CPU，2warmups+5trials/process、各10测量：480ticks总耗时median353.8145→360.074ms(+1.77%)，tick p50 603→649μs，p95 1473→1371.5μs，max7492→6809μs；setup median1315.5→1585μs。候选确实19/480ticks触达retract，双方无提前结束。仅Linux headless局部，不代表渲染FPS、全局预算或Windows/macOS性能通过。

## 独立最终B回归
- 普通99入口98通过；唯一失败入口是既有两项summit剑式6.82秒未达7秒目标，B没有新增85% boss节奏失败。更新器9/9通过；限流早醒的有界提示滞后诊断作为既有边界保留，未借放宽断言放行。
- 独立fresh earned boss≤35秒54/60=90%；canonical守/辅完全回到v16，A最差guard种子3/85的B战报除elapsed外恢复v16。Contract22,851/0、生产shutdown11/0；普通99日志无SCRIPT ERROR或泄漏警告。
- B实际Linux llvmpipe试招最终10/10，覆盖三招各retract/settle、retract精确暂停、实际伤害败北、反复退出/重入、正式状态不变；合成延长生命值fixture不冒充自然通关。正常生产_quit退出无泄漏警告。
- 广域64seed sensitivity未作为本轮完成证据，A尝试被主动中止，保留而不算通过/失败。

## 最终实际发行载荷验证（2026-10-23）
- B源清单966文件逐项核对，另冻结601个运行时/资源/config（含导入元数据）；全量重新导出Windows x86_64/macOS universal，未复用被拒绝的A包。两个内容ZIP各67脚本/109依赖路径当前源码一致。production Policy/Guard对实际PCK的manifest、SHA、大小、ABI1/schema4通过。
- Linux Godot4.6.3从空项目加载实际Windows EXE内载荷、实际Mac ZIP内PCK，无源码fallback。336活动资源全部加载；retract/settle实际Texture2D各256×256、PNG remap/ctex及sole锚115,232/121,232正确；两平台实际CanvasItem绘制各姿态8次通过。新锚审计最初以JSON浮点数组与整数数组直接比较误报；只修外部工具为size2+逐元素float严格数值检查，保留原始失败/独立诊断/重测证据，未改运行时。
- 实际两平台收势contract22,851/0、石灵机制3239/0、奖励228/19、装备153/UI12166/cache5、容量67/693/7238均通过。正常bootstrap与注入确认失败暂停/释放安全路径通过。
- 旧公开v1.3.10/v1.3.16各Windows/macOS原载荷，普通存档及100装备首通待领+已搜满尸体两场景、每场景两次启动，共16次mixed bootstrap启动通过。原bootstrap/store字节及内建版本不变；装备、战术/报告保留，v10迁移balanced。满包失败无部分奖励，显式整理和领取无重复；尸体派生hold可跨保存重启，只有亲自领取才推进击杀。试招不写正式存档。
- 更新器能力保持原安装边界：旧v10+新PCK仍无新限流方法且明示需完整安装；旧v16+新PCK保留既有保护。新v17完整包两平台真实Service HTTP fixture各67/0，另以两个独立进程证明等待持久化/连点抑制；只测试传输重定向localhost，生产传输不改，不冒充公网验收。
- 新v17完整包+已有合法v16 active PCK：两平台各两次启动，新Service/原内容release_panel兼容，无缺失方法；gear/战术/存档保持。实际gameplay仍v16，active记录未被清除，不将完整安装宣传为自动清更新记录。
- 保留main5916171全部8个CI文件原字节；现CI固定v16并非v17原生实包证明。正式封包另执行三ZIP全成员路径/CRC/原始字节敏感扫描、完整source与601hash及CI8核对，七资产SHA由清单给出。

这些结论属于Linux上的实际目标平台载荷验证，不是原生Windows/macOS GUI/DPI/GPU/签名公证或公网链实测。独立B原生Linux GUI/平衡证据见前节；现存两条summit节奏失败、全局性能预算与限流到期提示可能有界滞后不在本轮宣称解决。头部仍是离散关键帧且抬高略早，不宣称完全平滑。

---
## 历史 v16 验证（仅供继承功能追溯，不是v17实包证据）

# v1.3.16-test.1 构建验证

**完整包提供新版限流更新器。旧安装仅应用新 PCK 时保留旧预加载更新器，只有兼容说明界面；限流保护需要安装新版完整包。** 不改变 bootstrap ABI1 / 存档schema4。

## 已验证：源码与本地执行

- Godot 4.6.3.stable.official.7d41c59c4。
- 更新测试9入口共501检查全通过：pack guard38、panel rate63、既有panel21、policy160、proxy9、新rate policy55、真实HTTP rate service67、service47、store41。
- 新服务测试覆盖403 limit60/remaining0/reset、429 Retry-After、普通403、缺头、过去/远未来时间、自动和20连点抑制、频道切换、重开、到期手动重试、坏时钟/持久化字段，以及下载错误正文在临时文件中的primary/body-only/secondary限流。最后这一点由独立审查发现并修复，独立外部probe复测60秒等待且临时文件删除。
- 独立策略补测30检查通过；不将它们冒充源码测试数。
- 实际两个新的Godot进程、相同隔离用户目录、localhost HTTP fixture：第一个记录限流，第二个仍保持等待，频道切换和连点不重发。不是仅重建一个Node的模拟。
- 非更新完整聚合99入口：98通过，唯一失败入口 `test_encounter_balance.gd` 是既有4474检查中的两条summit剑式6.82秒小于7秒断言。未降低阈值，未宣称全绿。
- 180场earned-input基线的 encounters、campaigns、powered_replays、checks、failures 与v1.3.15全部相同；metadata中的源码hash正常变化。459个原asset文件逐字节不变，游戏规则/美术/透明/比例没有改动。
- Windows输出编码及ZIP安全驱动本地单元1+8通过。最终main `13a4361ac2355d0c924c77161256d95952e1e686` 的8个CI文件按SHA原样保留。

## 构建/发布验证的分层边界

此文初稿记录源码阶段；实际导出、资源白名单、旧bootstrap+新PCK、公开HTTP更新、原生平台执行必须等对应阶段完成后追加证据，不用fixture或旧版本CI代替。

- 新增rate policy与纯展示release_panel已列入三个导出preset白名单；PCK仍排除所有update_*，未变更旧Guard。
- native-package CI目前仍固定已发布v1.3.15资产的SHA/tag；它通过不能证明v1.3.16实际包通过。v1.3.16发布并核对字节后另行更新锁定值再验。
- 真实GUI发现最初裸控件测试遗漏125%内容缩放与纸面主题：旧主面板关闭按钮裁切、标题/禁用字低对比。已保留16/18px字体，局部调整颜色、压缩主布局并分成3页。控件测试在1200×400/1.25下主570×288、说明570×252–279（含pending/content明细）；真实GUI最终验收另记录，不将控件测试视为像素审查。
- 未宣称原生Windows/macOS GPU、Gatekeeper公证、跨平台帧率或正式版稳定性达标。
- 本轮只修更新体验，不解决既有头跳、同步耗时/帧预算和节奏失败。无需用户令牌，不绕公共API限流。

## 不可变更新器边界修复

构建预检用真实旧v15安装＋第一候选PCK发现原update_panel同样被update_*排除，故旧安装无法得到新提示；该候选没有发布。已只将展示/交互移至gameplay release_panel.gd，cultivation仅更换UI preload。Service、限流策略、Store、Policy、Guard没有换名塞入PCK，旧保护名单不变。独立审查确认应用/回退交易代码与原panel一致；实际旧载荷混合加载由构建门禁再验证。

## 最终实际发行载荷验证（2026-10-23）

- 基于 `runtime-freeze-v2.json` 的 11 个最终文件重新导出，另记录全部 595 个运行时/资源/config SHA；并非沿用发现面板投递缺陷前的包。Windows x86_64 与 macOS universal 均新鲜导出，两个内容 ZIP 的 67 个脚本及 109 个依赖路径逐项存在且等于源码。production Policy/Guard 对两个实际 PCK 与 manifest 的 size/SHA/ABI1/schema4 校验通过。
- 使用 Linux Godot 4.6.3 加载实际 Windows EXE 内载荷、实际 macOS ZIP 内 PCK，空项目目录，无源码 fallback：335 个活动资源、石灵新图256×256/import remap/ctex/锚点及8次实际CanvasItem绘制通过。奖励状态228/host19、装备状态153/UI12166/cache5、石灵15396/3239、容量67/693/7238检查均零失败；两平台正常bootstrap和注入确认失败后释放/暂停安全路径均通过。
- 实际两平台完整包打开更新界面，真实Service具备限流能力。对实际包内Service的外部HTTP fixture仅重定向传输到localhost：每平台67检查零失败；每平台另用两个独立进程证明等待持久化、频道切换/连点不会解除等待。测试断言未改，只桥接未随发行导出的测试fixture preload，留存源hash/桥接说明。此项不是GitHub公网更新验收。
- 真正公开的v1.3.10与v1.3.15 Windows/macOS原载荷，各覆盖普通存档与100装备首通待领、每例两次启动，共16次旧bootstrap启动。新PCK通过旧Guard，原bootstrap/store字节与内建版本保持不变；真实旧Service仍不具备限流接口，新release_panel正确显示“限流保护需安装新版完整包”。装备、资源、战术/报告保留（v10迁移balanced），试招不写正式进度；容量失败无部分领取，显式整理后领取一次，二次启动不重复领奖。下载PCK不包含update_*，没有绕不可变更新器边界。
- 另验完整v16安装遇到合法既有v15 active PCK：两平台各两次启动，新Service和update_panel兼容wrapper/release_panel正常，无缺失方法；gear/战术/存档保留。**此时实际gameplay仍显示v1.3.15-test.1，active记录保持原状；安装完整包不等于清除已有更新记录。** 此场景与“旧安装仅打新PCK”必须区分。
- 最终Linux/XFCE llvmpipe、Dummy audio原生界面：实际暂停游戏本地429等待/到期手动重试、1200×400条带125%缩放三页说明、960×540窗口、纸面主题标题/禁用字及底部按钮均通过。GUI中的旧能力替身只证明显示，不代替上面的真实旧包门禁；早期发现缺陷的截图不冒充最终hash。
- 最初独立Guard命令忘设可写XDG目录，宿主拒写/home/agent引擎退出；保留原日志，改为隔离可写测试目录后Guard通过。不是隐藏产品失败。所有测试存档均隔离，未操作用户真实存档。

以上为本地最终包门禁。仍未实测原生Windows/macOS GUI、签名/公证或真实音频；原有两条节奏失败、帧预算不足/头跳不因本轮更新器修复而宣称解决。首次候选未发布且已废弃。最终三ZIP逐成员路径/CRC/原始字节敏感信息扫描、源码CI8文件原hash审查与七资产SHA清单由发行封包门禁执行，记录在独立构建QA。
