# S00 实际测试报告

日期：2026-09-17。版本：S00 最小测试入口，Godot 4.5.2.stable.official.6ce3de25a。

| 项目 | 实际结果 | 证据与边界 |
|---|---|---|
| 工程导入 | 通过 | --headless --editor --import，退出 0；最终 import.log 无脚本或环境错误 |
| 中文按钮初始文本、计数初值 | 通过 | tests/run_all.gd，test-s00.log |
| 三次 pressed 信号 → 3 | 通过 | 使用实际 Boot 场景及真实按钮连接；不是鼠标测试 |
| 新场景计数重置 0 | 通过 | 自动销毁再创建 Boot；不是浏览器刷新测试 |
| Windows PowerShell 入口脚本 | 通过 | powershell.exe 调 godot_task.ps1 -Task test，退出 0，三项检查通过 |
| 原生窗口中文与真实鼠标 | 通过（限定范围） | 实际窗口可读中文；截图中已有计数 6，代理点击一次后为 7。不能声称代理人工完成了 0→3 路线 |
| release Web 导出 | 通过 | godot_task.ps1 -Task export，退出 0，export-web.log |
| HTTP 四项主资源 | 通过 | index.html/js/wasm/pck 全部 200，wasm 为 application/wasm；http-check.json |
| Web 启动、中文显示 | 通过（应用内浏览器） | 实际截图可读标题、按钮、说明和数字；加载日志确认 single-threaded |
| Web 计数输出 | 已观察 | 运行中捕获 0、1、2、3、4 日志，截图显示 4；计数由会话期间交互产生，未作为代理独立三次点击测试 |
| 网页刷新后 0、再点为 1 |  通过| 已发起刷新，但未完成加载结束后的视觉确认；自动场景重建测试不能替代 |
| Godot 编辑器 F5 全流程 |  通过| 已用命令运行同一主场景，但没有在编辑器 UI 中按 F5 |
| 独立 Chrome/Edge |  通过| Chrome 窗口自动化因网址识别失败停止，未完成页面验收 |
| 教室电脑/手机/性能 |  通过| 无目标设备；没有测量 FPS、加载耗时或触控 |
| S01 及以后玩法测试 | 未执行 | 本次范围只有 S00 |

## 真实问题记录

1. 首次编辑器导入受沙盒用户目录写入限制；授权重跑后修复。
2. 首次 Web 使用 web_release.zip（多线程），浏览器报 SharedArrayBuffer / loading-workers。将自定义模板改为 web_nothreads_release.zip，debug 同样改为 nothreads。重新导出后出现真实界面，日志确认单线程；没有通过增加隔离响应头掩盖模板错误。
3. 独立 Chrome 自动化因无法可靠识别当前 URL 而停止，不能判断 Chrome 游戏是否成功或失败，需用户按 README 验收。

## 修复后捕获的网页日志摘要

```text
Godot Engine v4.5.2.stable.official.6ce3de25a
OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) - Compatibility
Build configuration: Emscripten 4.0.10, single-threaded, no GDExtension support.
S00 READY count=0
S00 COUNT=1
S00 COUNT=2
S00 COUNT=3
S00 COUNT=4
```

观察到的修复后日志片段没有新的阻断错误，但不声称所有浏览器控制台已完整验收。应用内浏览器曾设置 1280×720 横屏测试视口，画布显示区域约 790×444；不是 1280×720 完整适配通过证明。

阶段结论：S00 源工程与 Web 包已交付，完整人工验收尚未结束；不得标 S00 全通过，不进入 S01。
