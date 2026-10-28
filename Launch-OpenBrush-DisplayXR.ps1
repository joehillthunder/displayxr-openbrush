# Launch Open Brush on the DisplayXR OpenXR runtime.
#
#   Launch-OpenBrush-DisplayXR.cmd                    installed runtime: 3D on the whole panel
#   Launch-OpenBrush-DisplayXR.cmd -Runtime dev       dev runtime: 3D inside the app's own window, F11 = whole panel
#   Launch-OpenBrush-DisplayXR.cmd -Runtime dev -Fullscreen   dev runtime, starting on the whole panel
#   Launch-OpenBrush-DisplayXR.cmd -AppExe <path>     a specific copy
#
# -Runtime dev needs a from-source DisplayXR build with the draft PRs listed in coupling.ps1:
# pass its manifest with -DevRuntimeJson, or set $DevRuntimeJson (and $AppExe) in a local.ps1 next
# to this script (not committed). The dev build's client must match the running displayxr-service.
#
# Depth: the camera rig is seeded every start from the runtime's display info (true geometry,
# see README). -GlassM sets the app distance (metres) that lands on the screen.
param(
	[ValidateSet("installed", "dev")] [string]$Runtime = "installed",
	[string]$DevRuntimeJson,
	[string]$AppExe,
	[double]$GlassM = 1.5,
	[switch]$Fullscreen,
	[Parameter(ValueFromRemainingArguments)] [string[]]$AppArgs
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\coupling.ps1"
if (Test-Path "$PSScriptRoot\local.ps1") { . "$PSScriptRoot\local.ps1" }

$exe = Find-App $AppExe
$processName = [IO.Path]::GetFileNameWithoutExtension($exe)

if ($Runtime -eq "dev") {
	if (-not $DevRuntimeJson -or -not (Test-Path $DevRuntimeJson)) {
		throw "-Runtime dev needs -DevRuntimeJson <path to the dev build's $($Coupling.RuntimeManifest)> (or `$DevRuntimeJson in local.ps1)."
	}
	$env:XR_RUNTIME_JSON = $DevRuntimeJson
	# 3D inside the app's own window: hosted-window embedding (DisplayXR PR #2332).
	$env:DXR_HOSTED_WINDOW = if ($Fullscreen) { "fullscreen" } else { "auto" }
	# Mouse = a controller hand under the cursor (#2347).
	$env:DXR_MOUSE_HAND = "1"
} else {
	# Released runtime: no embedding, the 3D opens on the whole panel.
	$env:XR_RUNTIME_JSON = Find-InstalledRuntime
}
if ($Coupling.DisableUltraleap) { $env:DISABLE_XR_APILAYER_ULTRALEAP_HAND_TRACKING_1 = "1" }

# Camera rig, re-seeded every start: true geometry (the 3D view maps 1:1 onto the panel from the
# nominal viewer), GlassM on the screen, infinity at the behind-screen comfort budget.
$cli = Join-Path (Split-Path $env:XR_RUNTIME_JSON) $Coupling.CliName
$rigArgs = @{ GlassM = $GlassM; Cli = $cli }
if ($Runtime -eq "dev") { $rigArgs.PitchDegrees = -15; $rigArgs.PullbackMeters = 0.6 }   # pitch / pull-back keys: dev runtime only (#2334)
try { $env:DXR_LEGACY_CAMERA_RIG = & "$PSScriptRoot\tools\New-TrueGeometryRig.ps1" @rigArgs }
catch { $env:DXR_LEGACY_CAMERA_RIG = "$PSScriptRoot\OpenBrush.exe.json" }
Write-Host "Runtime: $env:XR_RUNTIME_JSON"
Write-Host "App:     $exe"
Write-Host "Rig:     $env:DXR_LEGACY_CAMERA_RIG"

$startArgs = @{ FilePath = $exe; WorkingDirectory = (Split-Path $exe) }
if ($AppArgs) { $startArgs.ArgumentList = $AppArgs }
Start-Process @startArgs

if ($Runtime -eq "dev") {
	# Depth slider docked in the app window (Depth = stereo strength, Focus = what sits on the
	# screen; double-click = reset). Needs live depth (#2350).
	$pwsh = (Get-Process -Id $PID).Path
	Start-Process $pwsh -WindowStyle Hidden -ArgumentList "-NoProfile", "-File",
		"`"$PSScriptRoot\tools\DisplayXR-DepthSlider.ps1`"", "-Process", "`"$processName`"", "-RightGap", "40"
}
