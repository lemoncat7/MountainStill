# v1.3.19-test.1 · 章前敌情导航候选

测试候选，非正式版；发布状态以GitHub Release为准。独立代码审查已通过（386项导航回归、1512项额外检查）；Linux GUI已完成指定范围，完整回归110入口中109通过、1项保留既有两条节奏断言失败。实际两平台载荷和旧安装升级矩阵已通过；不宣称正式版达标。

## 玩家体验
历练「山路」页新增「本章敌情 ↗」：直接阅读本章守灵与实际应对说明，再自行决定是否点「镜中试招」。只翻页，不出发、不换路、不改变存档/RNG；试招仍无奖励、无消耗。结束试招后可点「返回山路」，回到原浏览章与分页。普通衣冠入口仍返回衣冠。

未完历练、待搜遗体、待选机缘不会被放弃或被试招覆盖；保留原有禁止试招条件。锁章只显示既有锁定说明。试招仍以当前搭配、满气血真气与固定种子运行，结果不是胜率预测，也不是当前残余真气路线的保证。

## 实现边界
- 只改 adventure_pages.gd / combat_insight_pages.gd / ink_pages.gd / player_journey_pages.gd 的导航与临时界面来源；新入口和返回按钮14逻辑像素。
- 不改战斗引擎、数值、装备比较公式、存档、RNG、已接受美术、透明/场景比例、试招准入与计时。
- Store/Service仅更新版本常量至1.3.19-test.1；项目/导出1.3.19。存档schema4、bootstrap ABI1不变，不要求为此功能替换安装内Service。
- 来源上下文仅host metadata，不入存档。普通衣冠入口、侧栏、显式札记目的地及机缘直接导航清除来源；合书保留当前阅读位置，重新翻书仍可返回，退出程序不会持久化此上下文。
- 旧按钮由既有detached-node防护拒绝；导航额外复核抽屉、页签、浏览章与drawer generation。显式动画换页/合书增加generation，普通重绘由按钮有效性防护负责。

## 基线与源码发布保护
基于v1.3.18生产树；最新main 6eb28d396a3d67de0410856d664632a1754537e3 的全部14项CI/workflow/tool/doc逐字节保留，source打包白名单同时补齐，避免下一次源码发布删除GUI CI。全main对比生产树的8项差异均在此清单内。CI中的包/GUI探测版本pin保持原样，不冒称已对v19运行原生CI。v19 tag经发布代理认证查询不存在；发布前仍须重新核查。

## 已执行检查
6组定向测试（practice pages/session/host/lifecycle/controls及campaign UI）均exit0；导航真实host专项386 checks /0fail，含读取快照、时钟/RNG不变、锁章/解锁动态分页、检查点与遗体机缘保护、取消和完成返回。包含跨札记目的地、待选机缘直接导航等生命周期检查。修后六组定向测试再次全部通过；464项美术/音频/字体及其元数据与v18逐字节一致。

独立审查发现跨札记/机缘的显式目的地会带回本轮旧章来源；仅对新增章来源清除过时覆盖层，已修复并补48项真实host检查。普通旧敌情覆盖衣冠链接的问题在v18也存在，不在本轮泛化修改。

最初实现有一处elif缩进解析失败，已修复重跑；测试最初把普通refresh误认为新generation，已分开真实旧按钮与显式新generation两种测试，保留失败日志，没有删除产品断言。一次未设置XDG的语法检查因不可写fontconfig缓存失败，按隔离XDG重跑解析通过，不作产品通过证据。

## 可复现命令
在源码根目录，先为每次运行建立独立临时目录，勿使用真实存档：

```sh
T=$(mktemp -d)
export XDG_DATA_HOME="$T/data" XDG_CONFIG_HOME="$T/config" XDG_CACHE_HOME="$T/cache"
godot --headless --editor --path . --import
godot --headless --path . --script res://tests/test_chapter_practice_navigation.gd
# 同样运行 test_practice_pages/session/host/lifecycle/controls_ui.gd 与 test_campaign_ui.gd
```

仍有既有正式版性能/稳定性阻断，本轮没有合入隔离native实验，也没有进行性能benchmark。

## 整合回归与原生范围（2026-10-23补充）

- 最终110个源码测试入口：109通过，唯一保留失败为既有balance两条节奏断言。首轮live_loadout_guard曾被OS终止exit-9，无脚本错误；GUI结束后低并发重跑119/0、exit0。两次结果分别保留，不把被终止的首轮记通过，也无证据断言是OOM。
- 官方editor import首轮也被OS终止；退出其他测试/GUI后单进程完整重导成功。未复用半成品；具体实际载荷与旧包矩阵以BUILD_VERIFICATION最终构建段为准。
- Linux真实GUI覆盖新档六章映射、锁章禁止试招、8→18敌条目动态索引、12.4秒自然试招与返回、R札记显式衣冠入口、真实换装对比、双击往返，以及960×540/1200×400、125%内容缩放。未完行程、待搜遗体（进度0.75秒）、待选机缘不能被试招覆盖。
- 机缘合成夹具载入时 travel_checkpoint 由0规范化为2，对应既有load_state规则，不是导航改变；奖励、选择与资源未变。作者及独立headless测试另在载入后取完整State/RNG/时钟快照，确认导航本身无变更。
- 这不是Windows/macOS原生GUI、GPU帧时、长期稳定性或新性能验收；本轮不合入隔离native性能实验。正式版原有性能/稳定性阻断仍保留。
- 打最终包前10:10 UTC再次读取GitHub main，仍为6eb28d396a3d67de0410856d664632a1754537e3；发布者提交前仍需核对新提交，不能覆盖较新的CI工作。

## 实际导出内容与旧安装兼容

最终Windows/macOS导出载荷均在Linux Godot中直接加载，不回退源码目录；资源依赖检查及新导航专项每平台386/0。旧v18/v10两平台的ordinary/capacity场景各两次启动（共16次）通过，保留原Service能力、装备、战术、战报、满100件装备的待领状态及尸体hold；旧bootstrap上的本章敌情/返回快照不变。新完整v19+旧active18两平台各两启保留旧内容，新限流Service仍可用。实际Service HTTP fixture每平台67/0，另含两进程持久化验证。这些不是GitHub公网更新或Windows/macOS原生GUI运行证据。

无新增导出依赖，无存档迁移，无ABI扩大。最终七件包的SHA与打包/敏感扫描由构建报告记录；不把完整源码或导出成功等同于正式版性能和稳定性通过。

完整原生报告：CHAPTER-PRACTICE-v1.3.19-NATIVE-GUI.md。本轮Linux GUI未独立操作Esc取消、无可用声卡；取消仅有真实host自动化覆盖，音效听感未验证。5次原生进程均exit0，候选与GUI副本70项源码复核一致。
