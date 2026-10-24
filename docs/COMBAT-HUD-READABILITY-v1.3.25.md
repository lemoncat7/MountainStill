# v1.3.25-test.1 战斗 HUD 可读性测试版（本地构建验收记录）

境界/暂停/路线、遭遇计数和战斗技能槽采用局部不透明纸底，非就绪技能文字提高对比度；保持坐标、字号、命中区域和全局透明效果。不改战斗公式、奖励、存档或更新 ABI。

**仍是测试版，不是正式版。** 2026-10-24 在恢复后的环境完成全新 Godot 4.6.3 导入与 Windows x86_64、macOS universal 实际导出。116 个普通入口中115通过；唯一失败入口仍是原4474检查中的2条剑式summit节奏断言，完整witness与前次逐字节一致（6.8161秒低于7.0下界）。此前被终止的live_loadout_guard本次未改测试，119检查/0失败。15个Python driver共183单测、2个真实多进程入口及源码HTTP重启通过。未放宽断言或把既有失败算作通过。

两新安装包由Linux Godot从空项目加载实际EXE嵌入载荷/实际Mac PCK：各HUD221、暂停归山376、provider62、章节1844、exact217、336活动资源及奖励/容量/装备矩阵通过。原公开v10/v24双平台普通与满箧场景共16次升级启动通过；新full25保留合法active24共4次启动通过；实际载荷localhost HTTP服务/两进程恢复共6阶段通过。正常启动、故障注入及更新面板验证通过。完整PCK与内容PCK逐成员核对本次导出，不是手工改装旧包。

敏感度沿用此前同一运行时与测量测试、同一earned快照SHA的5组64seed证据：17450检查/0失败、1920路线、5760场对决；**不是本次重跑**，也不是自然长期稳定性认证。此前同一HUD代码的Linux四场GUI夹具记录继续保留，不新增Windows/macOS原生GUI或声音通过声明。

恢复前3次导入终止与live_loadout的SIGKILL证据仍保留，根因未证。恢复中两处外部测试夹具路径/缺文件失败也保留；只修正测试夹具，以新状态完整重跑相应阶段。生产源码和导出包未为绕过这些失败而修改。

保持save schema4、Bootstrap ABI1及合法旧active内容优先规则：完整安装v25遇active24仍运行旧gameplay，需实际内容更新才得到新HUD。33.3ms CPU门槛、目标平台GUI/DPI/音频/GPU/FPS、长期可靠性、Windows签名和Apple Developer ID/公证仍未完成；Mac仅本地ad-hoc资源签名。不要关闭系统防护。以上是本地验收，不是公网发布/下载/更新链或发布后CI证明。

---
## 恢复前暂缓记录（历史快照；当前状态以上文为准）

# v1.3.25-test.1 战斗 HUD 可读性候选（暂缓构建，未发布）

境界/暂停/路线、遭遇计数和战斗技能槽采用局部不透明纸底，非就绪技能文字提高对比度；保留原坐标、字号、命中区域和全局透明效果。不改战斗公式、奖励、存档或更新 ABI。

**本轮整体回归未通过，不能作为可发布版本。** 已验证独立资源缓存下116个普通入口全部终态：114通过，保留encounter_balance原4474检查中的2条断言失败（6.8161秒低于7.0下界，完整witness与v24相同）；另live_loadout_guard进程被SIGKILL（-9、无完成marker），根因未证。没有修改测试或阈值掩盖失败。

15个Python driver共183单测、2个真实多进程入口及源码本地HTTP重启seed/verify通过。新HUD专项221/0，作者2270/0、独审几何3924/0；以上不是新安装包的运行证据。敏感度已完成5/5个build：64seeds×6chapters，17450checks、1920/1920routes、5760/5760duels，已完成分组0失败。这是当前earned快照的合成敏感度，不是自然长期可靠性或性能认证。

Linux实际GUI四个严格场景正常退出且脚本/音频bus错误为0：UI100%、960×540正常窗口和1200×320细条、明暗桌面，覆盖冷却、战气不足、空槽和clean-ready。保留镜像失败及初轮bus错误，未把它们计为通过。严格四场仍有PulseAudio/ALSA无声卡错误、Dummy回退和V-Sync警告；不称全日志clean或声音通过。这些是受控fixture GUI，不是Windows/macOS原生125%验收或新增自然六章证据。

三次Godot4.6.3 editor import分别以shell137、直接-9、受监-9终止；两次受控门禁均未启动下游。第一次QA启动误写exit0并误继续少量测试的原证据保留，已独立纠正并从最终116统计排除。**没有成功的本轮fresh editor import，没有新Windows/macOS包或内容PCK导出，也没有本轮实际包升级16boots、full25/active24四boots或actual-payload HTTP六阶段。** 不沿用v24结果冒充v25通过，不手工重封旧可执行文件。

保持schema4、Bootstrap ABI1和合法旧active内容优先规则；本候选仍为完整源码检查点。33.3ms CPU门槛、目标平台GUI/DPI/音频/GPU/FPS、签名/公证及正式长期可靠性仍开放。请勿关闭系统防护。详见`docs/COMBAT-HUD-READABILITY-v1.3.25.md`。


## 冻结、工具和实际边界

- 基于公开main `a4ba9971ccb0bb36e80f6df3d5cb6b3f4e98d6a2` 的58tools/10CI；只新增HUD source smoke第14入口和严格221单marker/双流错误负例。ANSI前缀诊断漏口在测试前修复，历史已发布v24 installed-package/research pins不变。
- `cultivation.gd` SHA256 `ae69e79d76420572ddf448cdc386c1fda963b5d2ee09bd162d210a505ff0ca15`；新HUD测试 `136fa968012f0b3fe9a4b0e4b22339d84c1d1b0b808470a42e86d7ba2566c7f7`。除预定身份推进与fixture为1.3.25-test.2外，其他runtime逐字继承冻结候选，没有prototype bundled updater。
- 466项资源/导入设置（assets464及根icon两项）逐SHA与冻结来源相同；408项Godot imported缓存129224113字节独立复制，逐SHA、204个源/目标MD5关联、异inode复核。未复制项目editor/session/uid/userdata；这不是fresh import成功，也不是运行时源码fallback。
- 三次失败已保存真实stdout/stderr/exit及错误初稿audit。第三次27个RSS样本观察峰493544kB、真实wait=-9，未超时；cgroup限额不可见，不能据此断言OOM或固定512MB限制。仅一次已批准工具级doc-cache复用试验也失败，此路线已停止。
- live_loadout_guard测试与v24逐字相同；其同步循环UI延迟释放是可疑既有压力路径，不是根因证明。该-9独立列为新阻塞，不重试、不加await改变测试，不算通过。
- 116入口统计来自从零重启的known-cache源码运行，初次中断的1个终态/第2个中止入口只作失败证据。shutdown_audio原契约无数字检查数，仍使用原明确marker，不虚造计数。
- 17Python入口为15driver/183单测与2真实多进程；bootstrap回退故障注入唯一精确ERROR行单独允许，其他双流诊断拒绝。源码HTTP两阶段与actual-payload HTTP六阶段严格区分，后者未运行。
- 新HUD221实际执行48个draw回调并验证状态/资源/RNG/hit regions不变；外置standalone和RefCounted桥已逐字等价独审，但没有新实际包可供本轮执行，静态桥审不等于actual-payload通过。
- GUI报告冻结SHA584f630a8cf90c670038b6bf660adf7d6c85cffd45e224babc62b4d9df99cd33，15项审计与原自然链24文件不变。私有GUI图/自然档/fixture save不进入本源码或公开包。

## 后续所需

需要能成功运行已核官方Godot4.6.3 editor import/export的授权构建环境与现有官方模板，并重新诊断和完成未改写的live_loadout_guard标准入口；根因未证，不能保证仅换环境就解决。不得为绕过问题修改生产配置/算法/阈值或冒用旧包。当前没有发布、推送、dispatch或正式质量承诺。完整源码和完整测试/失败证据保存在私有Library，供后续继续而非丢失工作。
