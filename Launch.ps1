param([switch]$Editor, [switch]$Test, [switch]$Check)
$ErrorActionPreference = 'Stop'
$projectPath = $PSScriptRoot
$workspacePath = Split-Path (Split-Path $projectPath -Parent) -Parent
# Override GODOT_EXE when moving this project to another computer.
$enginePath = $env:GODOT_EXE
if (-not $enginePath) {
    $enginePath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Godot\Godot_v4.7.2-stable_win64_console.exe'
}
$env:APPDATA = Join-Path $workspacePath 'work\app-data'
$env:LOCALAPPDATA = Join-Path $workspacePath 'work\local-app-data'
New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
if (-not (Test-Path -LiteralPath $enginePath)) { throw 'Set GODOT_EXE to Godot 4.7.2, or import project.godot in Godot.' }
# Register GDScript classes on a fresh checkout. No .NET SDK or build needed.
if ($Check -or -not (Test-Path (Join-Path $projectPath '.godot\global_script_class_cache.cfg'))) {
    $ErrorActionPreference = 'Continue'
    $importOutput = & $enginePath --headless --path $projectPath --editor --import --quit 2>&1
    $importCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    $importOutput | ForEach-Object { Write-Host $_ }
    if ($importCode -ne 0 -or ($importOutput -join "`n") -match 'SCRIPT ERROR|Parse Error|Failed to load script') { throw 'GDScript import failed.' }
}
if ($Check) { exit 0 }
if ($Test) {
    & $enginePath --headless --path $projectPath --fixed-fps 60 -- --self-test
    exit $LASTEXITCODE
}
$launchArgs = @('--path', ('"' + $projectPath + '"'))
if ($Editor) { $launchArgs += '--editor' }
Start-Process -FilePath $enginePath -ArgumentList $launchArgs
