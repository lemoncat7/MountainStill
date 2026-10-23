# v1.3.22-test.1：异常 provider 生命周期边界

## 最小修复
精确规划的可信provider检查先使用 `typeof(provider)!=TYPE_OBJECT`，再执行 `not is_instance_valid(provider)`，最后才访问脚本白名单。Godot4.6.3中的已free Node仍为TYPE_OBJECT，但对它做`is Object`会报SCRIPT ERROR；完整几何旧路径本来已将它视作null并回退，无需改其他几何代码。

只改此一行以及必要版本字段。正常内置剑、扇、徒手仍可剪枝；自定义/未知/无效provider不获得可信剪枝。Duel及其调用、候选顺序、strict-less、浮点计算、美术、save schema4和updater ABI1不变。不引入native扩展，不声称这是真实普通玩家崩溃，也不声称性能回退已解决。

## 可从实际PCK执行的自包含专项
`tests/test_provider_lifecycle_guard.gd`仅preload生产res://脚本；custom provider为脚本内部类，不依赖res://tests或旁边fixture。17个具名用例、62检查覆盖：实际free Node的类型/无效性；已free pose、strike、双provider的guard=false及trusted cold/warm与完整路径逐字节相等，再对照对应null；null/scalar/live unknown；正常内置三武器；stateful custom的回调次数；hero/enemy/definition深层dead。scalar/live unknown仅测试可信guard拒绝，不声称任意错误类型都能被完整几何接受。

源码：
```
python3 tools/qa_verify_provider_lifecycle.py --project . --output /tmp/mountainstill-lifecycle-source
```
先用Godot4.6.3完成当前源码的正常editor import，不能在缺导入资源时把错误日志当作产品结论。

实际包（由构建验收执行）：
```
python3 tools/qa_verify_provider_lifecycle.py --project /tmp/empty-project --main-pack /absolute/path/to/MountainStill-windows.pck --script /absolute/path/to/tests/test_provider_lifecycle_guard.gd --output /tmp/mountainstill-lifecycle-pck
```
`--main-pack`也可指实际Windows EXE内嵌载荷或macOS包提取的PCK；empty-project不得有源码runtime可回退。运行时只从实际包加载生产脚本。Linux执行载荷不等于Windows/macOS原生运行。

严格gate同时要求退出0、stdout和stderr无SCRIPT ERROR/Parse Error/ERROR、唯一完整有序17个用例marker、唯一schema1总结62checks/0failures和Godot4.6.3。`tests/provider_lifecycle_driver_test.py`验证script-error/exit0、缺case、截断、重复总结、零检查、失败断言及错误engine等不能误过。旧v21的62/0/exit0日志仍因9条SCRIPT ERROR被拒绝。

作者的27模式三方诊断、109项验证与完整cold/warm trace属于独立局部证据；本自包含专项是新增集成入口，不把二者计数合并成单个测试。完整包、GUI和全量回归以BUILD_VERIFICATION的本轮结果为准。

## 安装与 active 内容边界
已有安装只加载新 v22 PCK 即可得到这一游戏代码修复；不要求为该单行变更重装受保护更新服务。反之，完整安装 v22 若保留合法 active v21，按既有内容选择策略仍运行 v21 游戏代码，也仍保留其 provider 边界；不能把覆盖安装宣传为无条件切换到已修复内容。
旧安装挂载新PCK、完整包保留合法旧active的实际启动证据以本轮BUILD_VERIFICATION为准；不删除用户更新记录或改变回退选择。
