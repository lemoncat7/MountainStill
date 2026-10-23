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
