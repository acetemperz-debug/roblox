param(
    [string]$Luau = 'luau',
    [string]$Compiler = 'luau-compile',
    [string]$Python = 'python',
    [string]$Rojo = 'rojo'
)
$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    $sources = @(Get-ChildItem src,tests -Recurse -Filter '*.luau' |
        Where-Object Name -ne '.bundle.luau' | ForEach-Object FullName)
    & $Compiler --null @sources
    if ($LASTEXITCODE -ne 0) { throw 'Luau compilation failed' }
    & $Python -X utf8 tests/bundle.py
    if ($LASTEXITCODE -ne 0) { throw 'Test bundling failed' }
    & $Luau tests/.bundle.luau
    if ($LASTEXITCODE -ne 0) { throw 'Headless regression tests failed' }
    & $Python -X utf8 tools/build_place.py
    if ($LASTEXITCODE -ne 0) { throw 'Place generation failed' }
    $place = Join-Path ([System.IO.Path]::GetTempPath()) ('macrosoft-' + [guid]::NewGuid() + '.rbxlx')
    try {
        & $Rojo build default.project.json -o $place
        if ($LASTEXITCODE -ne 0) { throw 'Rojo build failed' }
    } finally {
        if (Test-Path -LiteralPath $place) { Remove-Item -LiteralPath $place }
    }
} finally {
    Pop-Location
}
