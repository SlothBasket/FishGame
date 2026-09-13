param([switch]$Editor, [switch]$Test)
$ErrorActionPreference = 'Stop'
$projectPath = $PSScriptRoot
$workspacePath = Split-Path (Split-Path $projectPath -Parent) -Parent
$enginePath = Join-Path $workspacePath 'work\godot-dotnet\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe'
$env:DOTNET_CLI_HOME = Join-Path $workspacePath 'work\dotnet-home'
$env:NUGET_PACKAGES = Join-Path $workspacePath 'work\nuget-packages'
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:APPDATA = Join-Path $workspacePath 'work\app-data'
$env:LOCALAPPDATA = Join-Path $workspacePath 'work\local-app-data'
New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
if (-not (Test-Path -LiteralPath $enginePath)) { throw 'Portable Godot .NET runtime missing. See README.md.' }
dotnet build (Join-Path $projectPath 'FishGame.csproj') --nologo
if ($LASTEXITCODE -ne 0) { throw 'C# build failed. See build output above.' }
if ($Test) { & $enginePath --headless --path $projectPath -- --self-test; exit $LASTEXITCODE }
$launchArgs = @('--path', ('"' + $projectPath + '"'))
if ($Editor) { $launchArgs += '--editor' }
Start-Process -FilePath $enginePath -ArgumentList $launchArgs
