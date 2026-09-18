# 晚安，羊羊

Godot 2D 固定等距视角的数学牧场游戏。当前提交保存 2026-09-18 的可运行研发版本；商店、PK 与完整美术仍在 Figma 定稿中，并非最终品质版本。

## 运行

1. 使用 Godot 4.7.2，Compatibility 渲染器。
2. Windows 上运行 `powershell -File tools/prepare-local-fonts.ps1`，从本机已安装的微软雅黑复制运行所需字体。字体不随仓库分发；其他平台需自行提供合法字体到同名路径。
3. 导入 `godot-paper-pasture/project.godot`，按 F6/F5 运行主场景 `scenes/game.tscn`。

## 当前内容

- 8 个 JSON 驱动关卡，选地/围栏计费、分牧场资源结算、商店与口算优惠、狼寻路、入夜判定、星级与存档。
- `scripts/rules.gd`：面积、周长、水岸、连通块、安全规则。
- `data/levels.json`：关卡与参考解；`tests/test_rules.gd`：规则测试。
- 已验证规则测试 157/157；实际操作走查到第 1 关建造、购买、返回牧场及入夜检查。尚未完成全 8 关人工通关和 Web 导出验收。
- 本次按要求冻结 Godot，后续先补齐 Figma 流程和资源，再交研发 Agent 实现。

测试命令：`godot --headless --path godot-paper-pasture --script tests/test_rules.gd`

## 设计来源

- [Figma V3 与资产拆分规范](https://www.figma.com/design/ZkzRpNIYgST2zidTswRVr6/?node-id=93-2)
- [Notion V3 规则及视觉资源](https://app.notion.com/p/V3-3deed9e618178114adc7dbb75a8f4bd7)

素材及产品设计属于本项目；未授予公共再分发许可。系统字体、引擎缓存、临时下载链接及本机存档不入库。
