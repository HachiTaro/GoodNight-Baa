# 实际开发环境

检查日期：2026-09-17。

- 工作区：`D:/Projects/GoodNight Baa`；初始只有 PDF、AI开发文档和既有 tmp 文件，没有 game 工程或开发记录。
- Godot：`C:/Users/34018/Downloads/Godot_v4.5.2-stable_win64_console.exe`。
- 编辑器 GUI：`C:/Users/34018/Downloads/Godot_v4.5.2-stable_win64.exe`。
- 实际 `--version`：`4.5.2.stable.official.6ce3de25a`。
- 渲染：Compatibility；原生运行日志识别 NVIDIA GeForce RTX 5060 Laptop GPU，OpenGL 3.3.0 NVIDIA 610.62。
- Python：`C:/Users/34018/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`，启动器只用标准库。
- 本机 Chrome 文件版本：152.0.7977.83；独立 Chrome 交互待验。
- 实际网页测试容器：Codex 应用内 Chromium，日志确认 WebGL 2.0 与 single-threaded；不能等同于教室电脑。
- 模板：官方 4.5.2 stable 整包内 version.txt 已读取为 4.5.2.stable。实际使用 `tools/templates/web_nothreads_debug.zip`、`web_nothreads_release.zip`；非 .NET，无 GDExtension。
- 模板来源：[官方版本页](https://godotengine.org/download/archive/4.5.2-stable/)，页面下载重定向到 `godot-releases.nbg1.your-objectstorage.com/4.5.2-stable/Godot_v4.5.2-stable_export_templates.tpz`。
- 中文字体：`assets/fonts/NotoSansCJKsc-Regular.otf`；许可 `assets/fonts/OFL.txt`；来自 [Noto 官方仓库](https://github.com/notofonts/noto-cjk/tree/main/Sans)。

## 已验证

编辑器无窗口导入成功；原生窗口启动与中文显示；三项自动检查；单线程 Web 导出；本地 HTTP 资源及 wasm MIME；应用内浏览器出现真实中文界面并产生日志计数；Windows PowerShell 启动脚本路径与中文编码。

## 未完整验证

编辑器界面内亲自按 F5 的完整流程、用户独立双击全部入口、独立 Chrome/Edge、刷新结束后的归零与再次点击、目标教室电脑、移动设备、性能和游戏流程。S00 没有存档系统，不能把场景归零测试描述成存档刷新恢复测试。

## 环境问题与处理

首次沙盒导入无法写 Godot 用户缓存/设置，授权重跑后成功；最新 import.log 无该错误。首次 Web 自定义模板误指向多线程文件，已修正为 nothreads 并重新导出、实际加载成功。原电脑操作工具在进一步操作 Chrome 时无法可靠识别网址而停止，因此该部分未继续自动操作。


## 2026-09-18 S01 增量验证

引擎与模板仍为4.5.2，未升级或安装插件。运行入口已是S01，S00说明见README_S00.md。

- Windows PowerShell启动器导入/测试：49个断言通过，退出0；日志改为docs/test-s01.log。
- 最终Web导出退出0；实际应用内Chromium默认1280×720导航及设置刷新验证通过，独立Chrome/Edge仍待测。
- NVIDIA OpenGL实际原生窗口960×540截图已生成，UI逻辑画布1280×720；layout-s01.log记录尺寸。
- 应用内浏览器尺寸覆盖到960×540时出现画布缩放/坐标异常，恢复默认后正常；不能写为Web小窗口验收通过，待独立浏览器复核。
- 设置保存在Godot user://settings_v1.cfg。原生程序默认目录为 %APPDATA%/Godot/app_userdata/晚安，羊羊；Web属于固定网址的本地存储，两者独立。
- 自动测试使用独立临时设置文件，结束后仅清理该测试文件，不改真实用户音量偏好。
- 本次真实设备声音听感、手机触控、教室电脑、性能未测。
