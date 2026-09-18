$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$fontTarget = Join-Path $projectRoot 'godot-paper-pasture/assets/fonts'
New-Item -ItemType Directory -Force -Path $fontTarget | Out-Null
$fontSource = Join-Path $env:WINDIR 'Fonts'
Copy-Item -LiteralPath (Join-Path $fontSource 'msyh.ttc') -Destination (Join-Path $fontTarget 'regular.ttc')
Copy-Item -LiteralPath (Join-Path $fontSource 'msyhbd.ttc') -Destination (Join-Path $fontTarget 'bold.ttc')
Write-Output 'Local installed fonts prepared. Do not redistribute these font files.'
