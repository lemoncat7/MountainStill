# quality-v1312 独立原生整合验收

2026-10-22 10:43–11:00 UTC；Linux XFCE/X11、Godot 4.6.3、llvmpipe Compatibility。未修改 runtime，未接触 GitHub 授权页。

## 结论
已测整合玩法与窗口路径无新阻断。独立复现并协助定位原生 AltF4 音频资源泄漏；实现者修后，实际原生试招退出和正式 bootstrap 重开退出均无 ObjectDB/resource 告警。不能据此称 Windows/macOS 实机或正式版整体性能通过。

## 源码绑定
初始 cultivation 2498252767d596fd147af5bf5a6053cc110ec37208c93035377c228d53c045a2；geometry 315cfec357dd06427feddad8d777614bd31701eba3e5a82d18d04faf816d371b；duel b94c39545d58c1891af5de9d63a84f82841d71ac8003d5be8327a3061abad3c4。
修后 cultivation ebf19da98e3218cb4b497d252ade06e99a83bfd36276f2a119bff411262dd729。source-postfix.sha256 与 source-end.sha256 完全一致。

## 存档与入口边界
- 第一阶段为 FIXTURE.json：realm9、bamboo_pass clear1、无装备、150% UI；隔离 XDG，非自然新档通关。通过真实 UI 完成听泉桥三战/首领/归山，生成3条正式战报及章节首通。
- fresh-data 是真正空目录新档，修复前启动的内存脚本，验证默认1340×720、行装、攻击11/防御0、首章敌情可进入。未实际翻到锁定敌页，不能宣称锁定页GUI已覆盖。
- POSTFIX-FIXTURE.json 在已完成章节的隔离档上只预置窗口尺寸/暂停/透明。修后第一次 res://main.tscn 直入（明确不是bootstrap），通过F2切换得到960×540与1200×400。
- 最后 launch-final.sh 使用正式 bootstrap，日志确认 UPDATE BOOT: 1.3.12-test.1；读取修后存档，UI显示强攻仍选中、暂停/条带/章节/3条正式战报保留。

## 已实际验证
1. 普通听泉桥战斗、暂停、守壳/露隙、尸体隐藏状态标记、三战完结归山。初次战中AltF4重开保留0/3已开始历练，敌情禁用试招；继续完成而不是丢档。
2. 浅溪石灵试招：均衡胜9.1秒/伤190/承4；暂停与继续；结束恢复山居暂停；强攻同敌再试显示耗时相同/承伤相同（本fixture无装备主动技能，不伪称展示了丰富构筑差异）。第三次条带试招可完成。
3. 960×540敌情解释、试招HUD、结果报告均可读；1200×400条带敌情、守壳试招、结果布局无裁切阻断。1340×720普通窗口初始阶段可用。人物与街景等比，没见纵横拉伸。
4. 真实桌面合成截图10/11：透明上方显示暗终端/白编辑器，局部纸底HUD与状态标记在两背景可读；没有把透明空白替换为黑幕。窗口截图黑区只代表透明，不等于桌面黑背景。
5. F8安全恢复会关闭透明并扩大到1340×720，属于既有安全恢复行为，不将03当透明证据。
6. 修改策略后保存重开，14显示强攻仍选中；试招没有新增正式战报，最终仍3条。

## 退出缺陷复现与修后验证
- ordinary-quit.log：初次普通战斗暂停后全局AltF4，无资源泄漏。
- second-verbose.log：普通三战归山→试招胜→结束→全局AltF4：ObjectDB，2资源仍占用；music.wav/equip.wav，各有AudioStreamWAV与AudioStreamPlaybackWAV引用。已把完整资源名交实现者。
- fresh-verbose.log 属修复前已启动进程，也有music.wav泄漏；不可误称修后失败。
- 实现者增加 SceneTree.auto_accept_quit=false，让WM关闭走已有保存及延时清理。修后实际进程（10:52:39启动前已记录ebf19da）完成三次试招→结束→全局AltF4，postfix-verbose.log 正常清理，无泄漏。
- 最终正式bootstrap重开→触发UI音效→全局AltF4，final-bootstrap.log 同样无泄漏/脚本解析异常。两个修后日志均实际加载music.wav和equip.wav。

## 限制
ALSA设备不可用，fallback Dummy；VSync模式驱动不支持。这些环境告警仍在，不宣称真实音频听感通过。未测试Windows/macOS、高DPI、长时间稳定性、所有武器、完整六章自然新档、所有策略构筑差异。性能门槛与既有战斗表现问题由独立性能/回归报告约束，本GUI测试不替代它们。

## 截图
01普通战中退出前，02尸体，03普通首领，04试招暂停，05试招报告，06真新档默认，07真新档首敌（非锁定），08修后960敌情，09修后960试招，10暗桌面，11亮桌面，12强攻比较，13条带守壳试招，14重开策略持久化。
