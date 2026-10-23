# 石灵状态标记：独立只读审查与原生 GUI 验收

时间：2026-10-22 10:30–10:39 UTC。候选 mechanic-candidate，基线 practice-candidate。
环境：Linux XFCE / X11 / Godot 4.6.3 / llvmpipe Compatibility；不是 Windows/macOS 实机。
结论：本渲染增量在已测范围通过，无新增布局阻断；不代表正式版整体性能/跨平台认证。

## 实际测试源码
scripts/cultivation.gd SHA256：2498252767d596fd147af5bf5a6053cc110ec37208c93035377c228d53c045a2。
开始/结束一致。diff -qr（排除 .godot）仅 cultivation.gd、test_stone_mechanic_view.gd、新说明文档变化。没有修改生产源码，没有发布，没有触碰 GitHub 授权页。

## 独立源码核对
- 新 _stone_mechanic_view 只读 duel_pose.mechanic，不依赖独立时钟或自行推算动作阶段。
- 源 enemy_attack_module.mechanic(enemy_turns)：偶数守壳0.90，奇数露隙1.12；duel_timeline._begin_action 在敌人开始动作时先增加 _enemy_turns。因此第一 enemy turn_started 就是露隙，不是攻击后/恢复阶段才露隙。
- 原始战斗/属性/存档/更新逻辑没有修改。普通历练与试招都走 _draw_encounter 的同一个新绘制调用。
- travel、pickup、结束/取消、敌人或玩家零HP、未知 mechanic、非溪桥、退出 encounter 都隐藏；暂停保留相同 pose。
- 仅局部纸底与三个石纹，无整身颜色乘算/暗化、全屏遮罩、身体盾罩，原美术和旧水弧保留。
- 独立执行测试：3239 checks、0 failures、进程退出0（independent-test.log）。这包含真实模拟普通/首领逐帧一致、首敌回合开始露隙、读视图不改pose/save、结束隐藏等断言。不是仅阅读实现者日志。

## Fixture 边界
初次官方 --campaign-demo 仍锁听泉桥，未冒称已解锁。退出后复制先前QA隔离存档为本目录独立 XDG_DATA_HOME，手动设置 realm=9、adventure.stage_clears.bamboo_pass=1（FIXTURE.json）。随后直接运行未修改项目，通过真实UI进入试招和普通历练。此为明确预置解锁fixture，不是自然新档通关，也不是用户真实存档。宽度/字体沿用QA设置，实际 UI/字号为150%。

## 原生实际操作/观察
- 1200×400条带：敌情第4页浅溪石灵，实际试招9.1秒胜，伤190/承4，结果页隐藏状态标记。普通敌与首领露隙纸底清楚，首领之后真实切换守壳（截图08）。
- 守壳暂停保持约25秒不变；继续/结束/Escape恢复原敌情页，场景返回山居，没有残留标记。
- 960×540普通窗口：首领露隙（10）可读，没有与名牌、敌血条、角色身体重叠。字体绘制14px，本次默认等比例world scale在960宽为1。
- 1340×880宽窗：首领露隙（11）可读，场景/人物保持等比，未见拉伸。实际宽窗高度880，不冒称720。
- 真实桌面合成：07暗终端、09白编辑器背景均可读；透明空白确实透出其后应用，未改成黑幕。03/04文件名虽有shell但图中仍是露隙；守壳证据以08/09为准。
- 普通历练：通过UI听泉桥整装出发；travel无新标记，fight真实守壳（12/13），第二敌fight仍守壳（14），第二敌已倒地时标签/石纹消失（15）。注意14名字写defeated但实际仍战中，以15才是尸体证据。暂停稳定。
- 本次角色没有装备武器，不能宣称所有兵器动画实机覆盖；标记位于敌人右上、与其血条和主角区域分离，源码检查无侵入武器路径的变化。
- 10:39正常关闭测试游戏与新开的空白编辑器，窗口清单无Godot，释放CUA。

## 警告与未覆盖
- 无音频设备：ALSA打开失败、fallback Dummy；VSync驱动不支持。未验证真实音频。
- 本次普通历练尸体阶段 Alt+F4 退出有 ObjectDB instances leaked / 1 resources still in use 警告。practice-native-qa/native.log 已存在完全相同警告，非本轮首次出现；未定位资源归属，不能据此称已修复或完全无错误。无运行中脚本/解析异常。
- 未做Windows/macOS、高DPI、长时性能或所有兵器动画。首回合切换精确时间、玩家死亡分支依赖独立实际模拟测试与源码，不冒称GUI逐帧捕捉。
- 本轮只验证渲染增量，原有战斗节奏失败/模型恢复硬切等不在本轮修复范围。
