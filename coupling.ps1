# Every Open Brush and DisplayXR runtime internal this integration depends on, in one place.
# NONE of these is a contract: they are observed behaviour of Open Brush 2.32.0 (Desktop build, Unity OpenXR, D3D11)
# and of the DisplayXR runtime (dev-runtime features: hosted-window embedding #2332, camera-rig
# pitch/pull-back #2334, mouse hand #2347, live depth #2350). Check them after any update.
$Coupling = @{
	# App
	ProcessName     = "OpenBrush"          # exe basename: slider target and per-exe atlas trigger tag
	ExeName         = "OpenBrush.exe"
	ExeEnv          = "OPENBRUSH_EXE"               # override: full path to the exe
	SteamFolder     = "Open Brush"               # steamapps\common\<this>, if it ships on Steam
	ZipGlob         = "OpenBrush_Desktop_*"             # unpacked release folders, newest wins
	# Unity players: the Ultraleap hand-tracking OpenXR layer (installed machine-wide by
	# Ultraleap's software) crashes the player inside xrEndFrame; disabled per process.
	DisableUltraleap = $true

	# DisplayXR runtime
	RuntimeUninstallName = "DisplayXR OpenXR Runtime"   # its InstallLocation holds the manifest below
	RuntimeManifest = "DisplayXR_win64.json"
	CliName         = "displayxr-cli.exe"               # next to the manifest; gives display info
}

# Install folder of an app from its Uninstall entry (machine or per-user, 64- or 32-bit view).
function Find-InstallLocation([string]$DisplayName) {
	$keys = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
		"HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
		"HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
	Get-ItemProperty $keys -ErrorAction SilentlyContinue |
		Where-Object { $_.DisplayName -eq $DisplayName -and $_.InstallLocation } |
		Select-Object -First 1 -ExpandProperty InstallLocation
}

function Find-InstalledRuntime {
	$dir = Find-InstallLocation $Coupling.RuntimeUninstallName
	if ($dir) {
		$json = Join-Path $dir $Coupling.RuntimeManifest
		if (Test-Path $json) { return $json }
	}
	# Fall back to the OpenXR registration.
	$avail = Get-Item "HKLM:\SOFTWARE\Khronos\OpenXR\1\AvailableRuntimes" -ErrorAction SilentlyContinue
	$json = $avail.Property | Where-Object { (Split-Path $_ -Leaf) -eq $Coupling.RuntimeManifest } | Select-Object -First 1
	if ($json -and (Test-Path $json)) { return $json }
	throw "The DisplayXR runtime is not installed. Install it from https://github.com/DisplayXR/displayxr-runtime/releases"
}

# Steam library folders (libraryfolders.vdf), if Steam is installed.
function Get-SteamLibraries {
	$steam = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamPath
	if (-not $steam) { return @() }
	$vdf = Join-Path $steam "steamapps\libraryfolders.vdf"
	$libs = @($steam)
	if (Test-Path $vdf) {
		$libs += Select-String -Path $vdf -Pattern '"path"\s+"([^"]+)"' |
			ForEach-Object { $_.Matches[0].Groups[1].Value -replace '\\\\', '\' }
	}
	$libs | Select-Object -Unique
}

# The app's exe: -AppExe, then the env override, then Steam, then unpacked release folders
# (newest first) in Downloads, LocalAppData\Programs and next to this script.
function Find-App([string]$AppExe) {
	if ($AppExe) { if (Test-Path $AppExe) { return (Resolve-Path $AppExe).Path }; throw "Not found: $AppExe" }
	$fromEnv = [Environment]::GetEnvironmentVariable($Coupling.ExeEnv)
	if ($fromEnv) { if (Test-Path $fromEnv) { return $fromEnv }; throw "$($Coupling.ExeEnv) points to a missing file: $fromEnv" }
	if ($Coupling.SteamFolder) {
		foreach ($lib in Get-SteamLibraries) {
			$exe = Join-Path $lib "steamapps\common\$($Coupling.SteamFolder)\$($Coupling.ExeName)"
			if (Test-Path $exe) { return $exe }
		}
	}
	if ($Coupling.ZipGlob) {
		$roots = "$env:USERPROFILE\Downloads", "$env:LOCALAPPDATA\Programs", $PSScriptRoot
		$exe = $roots | Where-Object { Test-Path $_ } |
			ForEach-Object { Get-ChildItem $_ -Directory -Filter $Coupling.ZipGlob -ErrorAction SilentlyContinue } |
			Sort-Object Name -Descending | ForEach-Object { Join-Path $_.FullName $Coupling.ExeName } |
			Where-Object { Test-Path $_ } | Select-Object -First 1
		if ($exe) { return $exe }
	}
	throw "Open Brush not found. Pass -AppExe <path to $($Coupling.ExeName)>, or set $($Coupling.ExeEnv). Get it from https://github.com/icosa-foundation/open-brush/releases (the Desktop zip) or Steam."
}
