$ErrorActionPreference = 'Stop'
try {
    $config = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'environment.json') -Raw | ConvertFrom-Json
    if (!(Test-Path -LiteralPath $config.python)) { throw '找不到 Python，请按 docs/README.md 更新 tools/environment.json。' }
    & $config.python -X utf8 (Join-Path $PSScriptRoot 'preview_web.py')
    exit $LASTEXITCODE
} catch {
    Write-Host $_ -ForegroundColor Red
    exit 1
}
