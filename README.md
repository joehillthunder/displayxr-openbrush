# DisplayXR for Open Brush

Run Open Brush's OpenXR (VR) mode on a DisplayXR 3D display (glasses-free, tracked) instead of a
headset. With the DisplayXR dev runtime the 3D sits inside the app's own window, next to other
3D apps.

Status: **work in progress.** Tested: Open Brush 2.32.0 (Desktop build, Unity OpenXR, D3D11) on Windows 11 x64, on DisplayXR's simulated
display. Framing, measured depth and input are still being calibrated.

## What's here

| File | Purpose |
|---|---|
| `Launch-OpenBrush-DisplayXR.cmd` / `.ps1` | Start the app on DisplayXR (installed runtime by default; `-Runtime dev` for the 3D in the app window, mouse hand and depth slider) |
| `coupling.ps1` | Every app / runtime internal this depends on (exe name, how the app is found, runtime registration). **Not a contract.** |
| `tools/New-TrueGeometryRig.ps1` | Seeds the DisplayXR legacy camera rig from the runtime's display info (see Depth) |
| `tools/DisplayXR-DepthSlider.ps1` | Depth / Focus slider docked in the app window (dev runtime) |
| `OpenBrush.exe.json` | Fallback rig, used only if display info can't be read |
| `local.ps1` (yours, not committed) | Machine-specific settings, e.g. `$DevRuntimeJson = "...\DisplayXR_win64.json"; $AppExe = "..."` |

## Use

1. Install the DisplayXR runtime from https://github.com/DisplayXR/displayxr-runtime/releases,
   or build it from source for `-Runtime dev`.
2. Get the app: https://github.com/icosa-foundation/open-brush/releases (the Desktop zip) or Steam.
3. `Launch-OpenBrush-DisplayXR.cmd` (add `-AppExe <path>` if it isn't found).

The launcher needs PowerShell 7 (`pwsh`). It runs under the default `RemoteSigned` execution
policy. If your policy blocks local unsigned scripts, unblock the files (`Unblock-File`) or sign
them; the launcher doesn't bypass the policy.

## Depth

The launcher seeds the legacy camera rig every start with a **true-geometry rig**, the same
calibration as DisplayXR's Blender, 3D Slicer and Twinmotion integrations:

- `verticalFov` is the 3D view's angular height from the nominal viewer, so the view maps 1:1 onto
  the panel.
- `convergenceDiopters` is 1 / `-GlassM`: app metres that land on the screen (default 1.5).
- `ipdFactor` puts infinity at the behind-screen comfort budget (0.42 % of the view width, a named
  constant until the runtime publishes one). The in-front budget (0.14 %) then holds for anything
  at least 0.75 × the screen distance away.

Panel size, resolution and viewer distance come from the runtime's display info
(`displayxr-cli status --json`); the constants in the script are fallbacks only. The rig is set at
start and doesn't follow the window: re-launch after resizing. Not yet measured for this app.

## Known issues

- Ultraleap's machine-wide hand-tracking OpenXR layer crashes the Unity player in `xrEndFrame`;
  the launcher sets `DISABLE_XR_APILAYER_ULTRALEAP_HAND_TRACKING_1=1` for this process only.
- Open Brush expects tracked controllers. Its suggested bindings include profiles DisplayXR doesn't
  provide (hp/mixed_reality, valve/frame); it falls back to khr/simple_controller.

## Where this is heading

DisplayXR's target for third-party apps is a host library with a texture hand-off or a dedicated
3D window: https://github.com/DisplayXR/displayxr-runtime/discussions/2331#discussioncomment-19185165. This launcher is the interim path, through the app's own OpenXR mode.

## Licence

Apache-2.0 (see LICENSE and NOTICE). The app itself is not included.
