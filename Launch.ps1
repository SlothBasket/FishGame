param([switch]$Editor, [switch]$Test, [switch]$Check, [switch]$HostGame, [switch]$AIVsAI, [string]$JoinIP, [ValidateRange(1024,65535)][int]$Port = 24567, [ValidateSet("fish","fisher")][string]$Role = "fish", [ValidateSet("","fish","fisher","both")][string]$AI = "", [double]$FishSkill = -1, [double]$FisherSkill = -1)
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
if ($AIVsAI) { $HostGame = $false; $launchArgs += @('--','--ai-vs-ai',"--port=$Port") }
if ($HostGame -and $JoinIP) { throw 'Choose HostGame or JoinIP, not both.' }
if ($HostGame) { $launchArgs += @('--','--host',"--port=$Port","--role=$Role","--ai=$AI") }
if ($AIVsAI -and $JoinIP) { throw 'AIVsAI is a local spectator session.' }
if ($JoinIP) {
    $parsedIP = $null
    if (-not [Net.IPAddress]::TryParse($JoinIP,[ref]$parsedIP)) { throw 'JoinIP must be an IP address (localhost is 127.0.0.1).' }
    $launchArgs += @('--',"--join=$JoinIP","--port=$Port","--role=$Role")
}
if ($FishSkill -ge 0 -or $FisherSkill -ge 0) {
    if (-not ($AIVsAI -or $HostGame)) { throw 'Skill overrides require AIVsAI or HostGame.' }
    if ($FishSkill -ge 0) { $launchArgs += "--fish-skill=$($FishSkill.ToString([Globalization.CultureInfo]::InvariantCulture))" }
    if ($FisherSkill -ge 0) { $launchArgs += "--fisher-skill=$($FisherSkill.ToString([Globalization.CultureInfo]::InvariantCulture))" }
}
Start-Process -FilePath $enginePath -ArgumentList $launchArgs -WindowStyle Hidden
