# 山海麻将 — 八地区五行 MVP

Godot 4.3+ / GDScript。打开根目录 `project.godot`，按 F5 运行。

## 已实现

- 八地区各一关：28/36/44/52/60/68/80/92张，5/7/8/9/10/11/12/14种宠物，每种初始至少一对。
- 经典上海麻将配对：正面无上层遮挡、同层同排左右至少一侧开放，允许跨层配对。水解放状态可绕过封锁。
- 初始牌局存在完整解法；火与风移除单张，允许奇数残牌和死局。洗牌保留剩余数量及牌位，只保证产生合法对子。
- 五行自动技能、无限思考时间的同元素Combo、未发现宠物保护。
- 有限撤回、洗牌、护佑、死局与失败、提示、暂停和下一关。
- 关卡解锁、新宠物手动发现及存档、可点选大图的图鉴。
- 导入现有36张宠物PNG的名称及元素，土使用棕色佔位；不修改原始美术。

完整玩法、五行效果、机制补充和配置字段见 [五行MVP说明](docs/MVP_FIVE_ELEMENTS.md)。产品目标仍为40关、八地区、60只灵兽；本轮没有完成全部内容或正式音效与特效。

## 操作

左侧按钮与左上选关菜单支持鼠标操作。快捷键：`R`重开、`Z`撤回、`H`提示、`S`洗牌、`N`下一关、`Esc`暂停。通关后解锁下一关，重新开始不清除收藏。

## 编辑与模块

宠物资料在 `scripts/data/pets.json`，关卡参数在 `scripts/data/levels.json`。保留36张24+8+4牌阵作为回归场景。

架构见 `docs/ARCHITECTURE.md`，AI约束见 `AGENTS.md`，美术标准见 `docs/ART_STYLE_GUIDE.md`。

打开 `scenes/tile_view.tscn` 可调整牌体、宠物区域、元素角标与颜色、土佔位颜色、水描边和消除淡出时长。打开 `scenes/board_view.tscn` 可调整间距与叠层偏移；牌尺寸应与tile_view保持一致。主界面按钮、图鉴与棋盘位置在 `scenes/main.tscn`。

遮挡计算使用 `BoardRules.FACE_RECT`，只覆盖米白色牌面，排除右侧及底部绿色厚度。调整尺寸或几何后应重跑规则测试。

## 验证

先运行 `godot --headless --path . --editor --import --quit`，再分别运行：

- `godot --headless --path . --script res://tests/test_board.gd`
- `godot --headless --path . --script res://tests/test_game.gd`
- `godot --headless --path . --script res://tests/test_mvp.gd`

测试使用独立存档文件；实际美术、鼠标与触屏手感还需试玩。可用有图形渲染的Godot运行 `tests/preview_mvp.gd`，将牌局和图鉴预览保存到 `.godot/`。

## 固定测试局与记录

右侧菜单可选择基础五行、Combo练习、孤牌残局三个独立测试局；不写入正式进度。填写整数种子后按R重开，正式牌局的抽取、分配和洗牌均可复现；重现技能还需要相同发现状态与操作顺序。留空则随机开局。

当前每局操作日志自动保存在Godot的 `user://playtests`，点击“查看记录路径”可复制路径。测试结论、玩法与限制见 [固定测试报告](docs/PLAYTEST_REPORT.md)，机器证据在 `docs/PLAYTEST_RESULTS.json`。可执行 `godot --headless --path . --script res://tests/test_playtests.gd` 重做10条对照与重播验证。

## 层级、锁定与胜利反馈

牌左上角显示所在层数；勾号表示可选，锁图示表示受阻。鼠标悬停或点击牌时，左侧会显示“上方压住”或“同层左右封锁”的原因，橙框标出相关阻挡牌。水解放牌继续以蓝框标识，并优先绘制与接收点击。

牌阵使用更明显的层间偏移与平面投影；原有牌体和宠物PNG保持不变。阴影、角标、颜色在tile_view的Inspector调整，层间偏移在board_view场景调整。修改几何后应运行 `tests/test_ui_feedback.gd`，该测试使用场景实际尺寸、间距与偏移验证八地区80条解法及锁定原因。

清空棋盘后显示胜利弹窗，可进入下一地区、再玩一次或查看棋盘。测试模式与最后一个地区不会出现“下一地区”。原有R/Z/H等快捷键保留。桌面渲染预览已检查，触屏手感仍待实际验证。

## 全地区开放与技能回馈

八地区现已全部开放。右下角“测试工具”（F1）默认收起，包含种子、五个独立测试局、记录路径与仅供测试的元素开关。新增“水开路”和“土护佑救局”可比较元素开/关的胜负差异。

五行有目标预告、短动效与新解锁牌闪亮，死局会弹出原因和可用操作。正式关卡使用元素对子配额，西陵起雷、土各至少五对；只代表数量条件，未证明每局能连续消到×5。目标选择会尽量避开破坏最后一对，仍保留单张技能和死局风险。

最新结果与限制见 [试玩及反馈更新报告](docs/RELEASE_FEEDBACK_REPORT.md)。新增检查：`godot --headless --path . --script res://tests/test_release_features.gd`。图形模式可运行 `tests/preview_release_features.gd` 验证动画时序与取消。
