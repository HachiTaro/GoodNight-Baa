param([ValidateSet('editor', 'test', 'export')][string]$Task = 'editor')
$ErrorActionPreference = 'Stop'
try {
    $projectRoot = Split-Path -Parent $PSScriptRoot
    $config = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'environment.json') -Raw | ConvertFrom-Json
    $engine = $config.godot
    if (!(Test-Path -LiteralPath $engine)) { throw '找不到 Godot，请按照 docs/README.md 配置编辑器路径。' }
    $version = (& $engine --version | Out-String).Trim()
    if ($version -ne $config.godot_version) { throw "Godot 版本不符：$version；需要 $($config.godot_version)" }
    if ($Task -eq 'editor') {
        & $engine --path $projectRoot --editor
        exit $LASTEXITCODE
    }
    & $engine --headless --path $projectRoot --editor --import --log-file (Join-Path $projectRoot 'docs/import.log')
    if ($LASTEXITCODE -ne 0) { throw '工程导入失败，请查看 docs/import.log。' }
    if (Select-String -LiteralPath (Join-Path $projectRoot 'docs/import.log') -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet) { throw '导入日志有错误，请查看 docs/import.log。' }
    if ($Task -eq 'test') {
        $logPath = Join-Path $projectRoot 'docs/test-s01.log'
        & $engine --headless --path $projectRoot --script res://tests/run_all.gd --log-file $logPath
    } else {
        foreach ($template in @('web_nothreads_debug.zip', 'web_nothreads_release.zip')) {
            if (!(Test-Path -LiteralPath (Join-Path $PSScriptRoot "templates/$template"))) { throw '缺少 4.5.2 Web 模板，请查看 docs/README.md。' }
        }
        New-Item -ItemType Directory -Force -Path (Join-Path $projectRoot 'builds/web') | Out-Null
        $logPath = Join-Path $projectRoot 'docs/export-web.log'
        & $engine --headless --path $projectRoot --export-release Web (Join-Path $projectRoot 'builds/web/index.html') --log-file $logPath
    }
    if ($LASTEXITCODE -ne 0) { throw "执行失败，请查看 $logPath" }
    if (Select-String -LiteralPath $logPath -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet) { throw "日志有错误，请查看 $logPath" }
    Write-Host '完成。请按 docs/README.md 继续验收。'
} catch {
    Write-Host $_ -ForegroundColor Red
    exit 1
}
