<#
.SYNOPSIS
  Print a true-geometry legacy camera rig (DXR_LEGACY_CAMERA_RIG JSON) for an
  off-the-shelf OpenXR app: the calibration used by DisplayXR's Blender, Slicer and Twinmotion integrations.

.DESCRIPTION
  The 3D view maps 1:1 onto the panel as seen from the nominal viewer:
    verticalFov         = 2*atan(h_view / 2 / z)       (z = nominal viewer distance, 0.6 m)
    convergenceDiopters = 1 / g                         (g = app distance that lands on the glass)
    ipdFactor           = K * w_view * g / (0.063 * z)  (parallax at infinity = K of the view width)
  K = 0.42 % (the calibrated behind-glass budget) keeps everything behind the glass
  comfortable; the 0.14 % front budget then holds for content at z >= 0.75 * g.
  Panel size, resolution and viewer distance come from `displayxr-cli status --json`;
  the constants below (a 15.6" 4K 3D laptop panel) are fallbacks only. Prints one line of compact JSON.

.EXAMPLE
  pwsh -File New-TrueGeometryRig.ps1 -GlassM 1.0 -ViewPx 1152x648
#>
param(
	# App-space distance (metres) that lands on the glass.
	[double]$GlassM = 1.0,
	# 3D view size in physical panel pixels ("WxH"); empty = the whole panel.
	[string]$ViewPx = '',
	# Parallax at infinity as a fraction of the view width (behind-glass budget).
	[double]$K = 0.0042,
	# Optional framing for apps whose work area sits below / too close to the start camera (dev runtime).
	[double]$PitchDegrees = 0,
	[double]$PullbackMeters = 0,
	[double]$IpdM = 0.063,
	# displayxr-cli.exe of the runtime in use; default: the installed runtime's.
	[string]$Cli = "$env:ProgramFiles\DisplayXR\Runtime\displayxr-cli.exe"
)

$d = [pscustomobject]@{ WidthM = 0.3444; HeightM = 0.2153; Z = 0.6; Px = 3840; Py = 2400 }
try {
	$env:IPC_IGNORE_VERSION = '1'
	$s = (& $Cli status --json 2>$null | Out-String | ConvertFrom-Json).screens |
		Where-Object { $_.roles.runtime_default } | Select-Object -First 1
	if ($s.layout.width_m -gt 0 -and $s.native.width -gt 0) {
		$d = [pscustomobject]@{ WidthM = $s.layout.width_m; HeightM = $s.layout.height_m
			Z = $s.layout.nominal_viewer_m.z; Px = $s.native.width; Py = $s.native.height }
	}
} catch { }
finally { Remove-Item Env:IPC_IGNORE_VERSION -ErrorAction SilentlyContinue }

$w = $d.WidthM; $h = $d.HeightM
if ($ViewPx -match '^(\d+)x(\d+)$') {
	$w = $d.WidthM * [int]$Matches[1] / $d.Px
	$h = $d.HeightM * [int]$Matches[2] / $d.Py
}
$rig = [ordered]@{
	convergenceDiopters = [math]::Round(1.0 / $GlassM, 4)
	verticalFov         = [math]::Round(2 * [math]::Atan($h / 2 / $d.Z), 4)
	ipdFactor           = [math]::Round($K * $w * $GlassM / ($IpdM * $d.Z), 4)
}
if ($PitchDegrees -ne 0) { $rig.pitchDegrees = $PitchDegrees }
if ($PullbackMeters -ne 0) { $rig.pullbackMeters = $PullbackMeters }
$rig | ConvertTo-Json -Compress
