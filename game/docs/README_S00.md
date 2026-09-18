# S00：运行与验收

目前只有中文测试页，不是完整游戏。原有策划及 AI开发文档均保留；尚未进入 S01。

## 1. 在浏览器验收（最简单）

1. 在文件管理器打开 `D:\Projects\GoodNight Baa\game`。
2. 双击 `preview_web.cmd`，保持出现的预览窗口开启。浏览器将打开 `http://127.0.0.1:8060/`。如果没有自动打开，把此地址复制到 Chrome 或 Edge 的地址栏。
3. 等待加载，看到“晚安，羊羊”“开始测试”和“点击次数：0”。中文不能是方框。
4. 用鼠标依次点击“开始测试”三次，每次应只增加 1，最后显示“点击次数：3”。
5. 点击浏览器工具栏的刷新按钮，等加载完成，应重新显示 0；再点一次应为 1。本阶段没有存档，归零是预期行为。
6. 完成后关闭预览窗口，服务停止。不要双击 `builds/web/index.html`，不要只移动 HTML 文件。

若提示端口已占用：先访问上述地址；若已有本项目页面，可直接验收。否则关闭之前的预览窗口再双击启动，不要结束不认识的进程。

## 2. 在 Godot 验收

1. 双击 `open_editor.cmd`。等待工程扫描完成。
2. 按 F5 运行整个工程。主场景已设置为 `scenes/app/Boot.tscn`。
3. 检查中文标题，连续点击三次，从 0 到 3。
4. 关闭游戏窗口，回编辑器重新 F5，初始值应为 0。

也可手动打开 `C:\Users\34018\Downloads\Godot_v4.5.2-stable_win64.exe`，在项目管理器“导入”中选 `game/project.godot`。

## 3. 重新测试、导出

- 双击 `run_tests.cmd`：导入并运行三项 S00 自动检查，完成后窗口保留结果。日志在 `docs/test-s00.log`；自动按钮信号测试不代替真实鼠标验收。
- 双击 `export_web.cmd`：重新生成完整网页包，然后刷新浏览器。日志在 `docs/export-web.log`。
- 改文案：编辑 `content/text/zh_CN.json` 的文字值，保留键名和 `{count}`；修改后需要重新导出才能反映到网页。
- 入口调用的执行策略只对该次脚本进程有效，不更改 Windows 的永久安全策略。

## 4. 换电脑或环境路径失效

当前电脑已准备好编辑器、模板、中文字体及 Python。路径集中在 `tools/environment.json`。

1. 从 [Godot 4.5.2 官方归档](https://godotengine.org/download/archive/4.5.2-stable/) 下载 Windows x86_64 **Standard**，解压到固定目录，不选 .NET。
2. 将 `tools/environment.json` 的 `godot` 改成解压后的 console.exe 完整路径，路径中使用 `/`。不要升级版本。
3. 同一官方页面下载 Standard Export templates（.tpz）。该文件是 ZIP；用解压工具打开，取其中 `templates/web_nothreads_debug.zip` 和 `templates/web_nothreads_release.zip` 两个文件，原样放进 `game/tools/templates/`。不要把这两个内层 ZIP 再解压，也不要误用 `web_debug.zip`/`web_release.zip`。
4. 本项目使用项目内自定义模板，无需写到系统模板目录。如选择编辑器模板管理器，安装同版本后还需清除导出预设中的自定义模板路径，才能改用全局模板；本机无需这样做。
5. 预览工具使用 Python 3 标准库；换电脑已有 Python 时更新 environment.json 的 `python` 路径。缺失时可从 [Python 官方 Windows 下载页](https://www.python.org/downloads/windows/) 安装 Python 3 后填写其完整路径。无需额外库。

## 5. 验收反馈

请记录：Godot F5 是否显示中文、三次点击是否为 3；Chrome/Edge 是否显示中文、三次是否为 3、刷新是否为 0、刷新后再点是否为 1。有问题请提供第一条报错或截图和操作顺序。

当前实际测试范围见 `TEST_REPORT_S00.md`。所有人工待验项确认后才记录 S00 完整通过；收到下一阶段指令前保持 S00，不自动开发 S01。
