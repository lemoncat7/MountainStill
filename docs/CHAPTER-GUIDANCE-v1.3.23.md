# v1.3.23-test.1 动态章节目标测试版

已通章重读现在显示真实后续目标；在途/暂停、遗物、机缘和首通待领仍优先。达到炼气中期后重读青竹关，不再重复要求同一突破。显示复用 State 真实门槛，不自动跳章、启程、领奖或改存档/战斗规则。

本轮普通回归 **114入口：113通过，保留 encounter_balance 原4474检查中的2条节奏失败**（同一剑式summit案例6.82秒低于7.0下界，阈值未改）。另15个Python driver共179单测及2个真实多进程入口通过；特殊敏感度与产物Guard单列，详见本轮报告。

Windows实际EXE嵌入载荷和macOS实际PCK均由Linux Godot4.6.3从空project加载；章节目标1844、provider62、exact217等检查通过。旧v10/v22双平台升级共16个启动case最终通过，新fullv23保留activev22共4次启动，本地实际载荷HTTP共6阶段通过。矩阵初次有1个进程被外部终止exit -9；保留原日志和合成状态、清理已验证可恢复副本后，以全新fixture串行重测通过，未确认OOM根因。**这些不等于Windows/macOS本机GUI、签名、公证或公网更新链验收。**

真实自然档副本的Linux GUI验证了960×540和1200×400、125%字号、暂停优先、取消/确认放下、正文/tooltip一致和本章敌情返回，正常exit0；不是六章自然全通或目标系统GUI。原自然存档未修改。

保持save schema4、Bootstrap ABI1与更新选择策略：新完整包如已有合法active v22，仍运行旧gameplay；实际更新内容后才得到新文案。没有混入bundle本地安装实验或微优化。现有33.3ms CPU正式门槛未解决；仍无Windows代码签名、无Apple Developer ID/公证，不能称正式版或性能改善。

目标包：`MountainStill-v1.3.23-test.1-Windows-x86_64.zip`、`MountainStill-v1.3.23-test.1-macOS-Universal.zip`。不要关闭系统防护绕过提示。详见 `docs/CHAPTER-GUIDANCE-v1.3.23.md`。此包记录本地构建验收；发布/公共下载/原生CI另由发布阶段证明。


## 冻结与回归证据

- 运行逻辑只改 `scripts/adventure_pages.gd`，SHA256 `9d405d37c97173c0d65d11954f506494facf19c1c4428ce95c294f89b5fde2b2`。Service/Store只升内置身份；Bootstrap/Policy/Guard/State/content/美术逐字保留。
- 继承main `a6978ea8dd6fc2d04fef28c456a01f924ba4750c` 全部tools与10CI；新增第12个native source smoke入口为章节目标UI，并严格拒绝0checks/错误/非零退出。历史native package及研究pins不改；注册不等于运行新native CI。
- 普通104 gameplay+10 updater隔离HOME/XDG，updater串行；113/114严格通过，唯一预先声明的balance两断言保留。stdout/stderr/退出码及SHA在内部QA。
- 15离线Python入口179单测；bootstrap_process真实pending/activate/mount/嵌套preload/双启/故障回退/singleton、update_rate_restart实际两进程均通过。首次bootstrap测得陈旧正例fixture `1.3.10-test.2` 被当前Store正确拒绝并超时；只把该正例和两处期望同步为 `1.3.23-test.2` 后重测通过，未松任何生产Guard。旧源码同字节仅是静态事实，未声称旧v22该入口曾实测失败；首轮失败日志保留。以后升版本需同时审这两个正例文件。
- 特殊敏感度单列：本轮balance earned报告+当前source_sha256，64 seeds×5 builds×6 chapters，共1920路样本，1920完整胜利、5760实际对决，17450checks、0failures。属于synthetic earned快照敏感度，不是自然游玩或性能门禁。
- 另一特殊入口 `update_release_artifacts_test.gd` 对本轮两PCK/manifest实际size/SHA/schema4/ABI1及namespace Guard通过。

## 实际载荷与兼容边界

- 官方4.6.3模板新导出；Windows AMD64的真实VS_VERSION_INFO file/product为1.3.23.0；macOS universal arm64+x86_64，plist1.3.23、可执行mode及ad-hoc资源结构通过。静态结构不是有效Developer ID或公证。
- actual EXE/Mac PCK从空project载入，核Adventure真实文件SHA；两载荷章节1844专项、生命周期17ordered cases/62checks、exact217、装备/容量/尸体/练习控制/石灵资源与更新策略/截止通过。
- oldv10/v22×Win/Mac×普通/满箧待领ready-corpse×首启/再启=16boots。每次挂入新PCK后运行同1844专项桥接、provider62/exact217，正式State与save哈希保持；旧Bootstrap/Service/Store SHA保留。Bridge仅改外部测试生命周期，断言体不变。
- fullv23+合法activev22两平台连续两启=4boots：真实新Service/Store哈希与旧Adventure哈希同时成立；保留装备、战术、存档、active记录，旧guidance仍可能存在。这是原有选择策略，未偷偷改变。
- 实际载荷本地HTTP Service/backoff/限流seed/verify共6阶段；生产transport不变，外部fixture桥接只改测试preload路径且保留同字节证明。

## 真实GUI与未验项

候选自然档副本Linux GUI摘要见 `CHAPTER-GUIDANCE-v22-CANDIDATE.md`，独立完整报告保留于私有证据；原始截图与v22自然玩法证据分别保留于独立私有QA。真实主备save仅内部私有证据，不进源码或发行包。首载自然采集与确认放下造成的预期差异已单独披露；取消不改gameplay。云音频Dummy/VSync环境警告保留，不能说原生日志全无错误。

本构建没有执行发布、推送或dispatch；目标Windows/macOS原生源码/安装包CI、GUI/DPI/音频/GPU/FPS、签名/公证、完整native升级链和公共下载验收均不能凭本报告冒称通过。既有CPU33.3ms门槛失败仍开放。
