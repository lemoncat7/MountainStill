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
