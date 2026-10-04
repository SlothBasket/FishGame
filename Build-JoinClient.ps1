param([string]$GodotExe = $env:GODOT_EXE, [string]$Template)
$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
$workspace = Split-Path (Split-Path $repo -Parent) -Parent
if (-not $GodotExe) { $GodotExe = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Godot/Godot_v4.7.2-stable_win64_console.exe' }
$env:APPDATA = Join-Path $workspace 'work/app-data'
$env:LOCALAPPDATA = Join-Path $workspace 'work/local-app-data'
if (-not $Template) { $Template = Join-Path $env:APPDATA 'Godot/export_templates/4.7.2.stable/windows_release_x86_64.exe' }
if (-not (Test-Path -LiteralPath $Template)) { throw 'Install the matching Windows release template or supply -Template.' }
$revision = (& git -C $repo rev-parse --short HEAD).Trim()
$version = $revision + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
$stage = Join-Path $workspace ('work/join-build-' + $version)
$output = Join-Path $workspace ('outputs/Share/Pelagic-Join-' + $version)
New-Item -ItemType Directory -Path $stage,$output -Force | Out-Null
# Copy game resources only, never .git, movies, reports or personal settings.
foreach ($directory in @('Scripts','Scenes','Shaders','Audio')) {
    Copy-Item -LiteralPath (Join-Path $repo $directory) -Destination $stage -Recurse
}
foreach ($relative in @('Scripts/DevLauncher.gd','Scripts/DevLauncher.gd.uid','Scenes/DevLauncher.tscn','Scripts/CaptureWorkflowChecks.gd','Scripts/CaptureWorkflowChecks.gd.uid','Scripts/HuntingChecks.gd','Scripts/HuntingChecks.gd.uid')) {
    $target = Join-Path $stage $relative
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target }
}
$config = Get-Content -LiteralPath (Join-Path $repo 'project.godot') -Raw
$config = $config.Replace('res://Scenes/DevLauncher.tscn','res://Scenes/JoinMenu.tscn')
$config = $config.Replace('[application]', "[application]`n`njoin_only=true`nconfig/version=`"$version`"`nconfig/use_custom_user_dir=true`nconfig/custom_user_dir_name=`"Pelagic Join`"")
Set-Content -LiteralPath (Join-Path $stage 'project.godot') -Value $config -Encoding utf8
$templatePath = (Resolve-Path -LiteralPath $Template).Path.Replace('\','/')
$preset = @"
[preset.0]
name="Join Only Windows"
platform="Windows Desktop"
runnable=true
custom_features="join_only"
export_filter="all_resources"
include_filter=""
exclude_filter="*.md,*.ps1,*.avi,*.csv,*.log,*.zip,*.json,*.txt"
export_path=""
script_export_mode=2
[preset.0.options]
custom_template/release="$templatePath"
binary_format/architecture="x86_64"
binary_format/embed_pck=true
application/modify_resources=false
codesign/enable=false
"@
Set-Content -LiteralPath (Join-Path $stage 'export_presets.cfg') -Value $preset -Encoding utf8
& $GodotExe --headless --path $stage --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Join-client import failed.' }
& $GodotExe --headless --path $stage --export-release 'Join Only Windows' (Join-Path $output 'Pelagic Join.exe')
if ($LASTEXITCODE -ne 0) { throw 'Join-client export failed.' }
Copy-Item -LiteralPath (Join-Path $repo 'PLAYTEST_JOIN_GUIDE.txt') -Destination (Join-Path $output 'START HERE.txt')
Set-Content -LiteralPath (Join-Path $output 'BUILD.txt') -Value "Pelagic join-only playtest`nBuild: $version`nGodot: 4.7.2 stable`nSource: $revision`nHost and client should use matching source versions."
$licenses = @'
extends SceneTree
func _initialize() -> void:
    var output = FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE)
    output.store_string(Engine.get_license_text()+"\n\n"+JSON.stringify(Engine.get_copyright_info(),"  ")+"\n\n"+JSON.stringify(Engine.get_license_info(),"  "))
    quit()
'@
$licenseScript = Join-Path $stage 'licenses.gd'
Set-Content -LiteralPath $licenseScript -Value $licenses -Encoding utf8
& $GodotExe --headless --path $stage --script $licenseScript -- (Join-Path $output 'GODOT-LICENSES.txt')
if ($LASTEXITCODE -ne 0) { throw 'Could not generate license notices.' }
$zip = $output + '.zip'
Compress-Archive -LiteralPath (Get-ChildItem -LiteralPath $output -File).FullName -DestinationPath $zip
Write-Host "SEND THIS ZIP: $zip"
Write-Host "Staged join-only project: $stage"
