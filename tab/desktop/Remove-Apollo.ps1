<#
  DUSTEX | takes Apollo (the Moonlight stream host) back off this PC and puts the screens back the way the dashboard wants:
  both monitors on and extended, each at 3440x1440 and its fastest refresh rate, and the spanned DUSTEX wallpaper.
#>
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""; return
}
$here = Split-Path -Parent $PSCommandPath
function Say($t, $c = 'Gray') { Write-Host $t -ForegroundColor $c }
Say "`nDUSTEX  |  remove Apollo and restore the screens`n" 'Yellow'
$a = Read-Host 'Uninstall Apollo and its virtual display driver? (Y/N)'
if ($a -match '^[Yy]') {
    try { Stop-Service ApolloService -Force -ErrorAction SilentlyContinue } catch {}
    Get-Process sunshine -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    $done = $false
    foreach ($k in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*') {
        Get-ItemProperty $k -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Apollo*' -and $_.UninstallString } | ForEach-Object {
            $u = $_.UninstallString; Say "Running Apollo's uninstaller..." 'Cyan'
            if ($u -match '^"([^"]+)"\s*(.*)$') { Start-Process $Matches[1] -ArgumentList "$($Matches[2]) /S".Trim() -Wait } else { Start-Process $u -ArgumentList '/S' -Wait }
            $done = $true
        }
    }
    if (-not $done) { Say 'Asking winget to remove it...' 'Cyan'; winget uninstall -e --id ClassicOldSong.Apollo --silent 2>&1 | Out-Host }
    # its virtual screen driver (SudoVDA), if it stayed behind
    Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -match 'SudoMaker|SudoVDA|Virtual Display Adapter' } | ForEach-Object {
        Say "Removing $($_.FriendlyName)" 'Cyan'; & pnputil /remove-device $_.InstanceId | Out-Null
    }
    try { & sc.exe delete ApolloService | Out-Null } catch {}
    Say 'Apollo removed.' 'Green'
}
# our old Apollo helper files and its signal file
foreach ($f in 'TabRemote.ps1', 'Setup-iPadRemote.ps1', 'Set up iPad Remote.cmd', 'tab-studio-boxart.png', 'ipad-remote-setup.log') { Remove-Item (Join-Path $here $f) -Force -ErrorAction SilentlyContinue }
Get-ChildItem 'C:\Users\*\AppData\Local\DUSTEX\TabWidget\remote.json' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

# ---- screens: both on and extended, full resolution, fastest refresh
Add-Type @'
using System; using System.Runtime.InteropServices;
public static class DxDisp {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] public struct DD { public int cb; [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string Name; [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string Str; public int Flags; [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string Id; [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string Key; }
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] public struct DM {
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName; public short dmSpecVersion, dmDriverVersion, dmSize, dmDriverExtra; public int dmFields;
    public int dmPositionX, dmPositionY, dmDisplayOrientation, dmDisplayFixedOutput; public short dmColor, dmDuplex, dmYResolution, dmTTOption, dmCollate;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName; public short dmLogPixels; public int dmBitsPerPel, dmPelsWidth, dmPelsHeight, dmDisplayFlags, dmDisplayFrequency;
    public int dmICMMethod, dmICMIntent, dmMediaType, dmDitherType, dmReserved1, dmReserved2, dmPanningWidth, dmPanningHeight; }
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern bool EnumDisplayDevices(string dev, int i, ref DD dd, int flags);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern bool EnumDisplaySettings(string dev, int mode, ref DM dm);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int ChangeDisplaySettingsEx(string dev, ref DM dm, IntPtr h, int flags, IntPtr p);
}
'@
try { Start-Process "$env:SystemRoot\System32\DisplaySwitch.exe" -ArgumentList '/extend' -Wait; Start-Sleep 3 } catch {}
$i = 0; $dd = New-Object DxDisp+DD; $dd.cb = [Runtime.InteropServices.Marshal]::SizeOf($dd)
while ([DxDisp]::EnumDisplayDevices($null, $i, [ref]$dd, 0)) {
    $i++
    if (($dd.Flags -band 1) -eq 0 -or $dd.Str -match 'Virtual|SudoMaker|Mirage|IddCx') { $dd.cb = [Runtime.InteropServices.Marshal]::SizeOf($dd); continue }   # only real, attached screens
    $cur = New-Object DxDisp+DM; $cur.dmSize = [Runtime.InteropServices.Marshal]::SizeOf($cur); [void][DxDisp]::EnumDisplaySettings($dd.Name, -1, [ref]$cur)
    # the dashboard's size per screen is 3440x1440; if this screen has no such mode, keep its size and only fix the refresh rate
    $tw = $cur.dmPelsWidth; $th = $cur.dmPelsHeight; $probe = New-Object DxDisp+DM; $probe.dmSize = $cur.dmSize; $pm = 0
    while ([DxDisp]::EnumDisplaySettings($dd.Name, $pm, [ref]$probe)) { $pm++; if ($probe.dmPelsWidth -eq 3440 -and $probe.dmPelsHeight -eq 1440) { $tw = 3440; $th = 1440; break } }
    $best = $null; $m = 0; $dm = New-Object DxDisp+DM; $dm.dmSize = $cur.dmSize
    while ([DxDisp]::EnumDisplaySettings($dd.Name, $m, [ref]$dm)) {
        $m++
        if ($dm.dmBitsPerPel -lt 32 -or $dm.dmPelsWidth -ne $tw -or $dm.dmPelsHeight -ne $th) { continue }
        if (-not $best -or $dm.dmDisplayFrequency -gt $best.dmDisplayFrequency) { $best = $dm }
    }
    $was = "$($cur.dmPelsWidth)x$($cur.dmPelsHeight) @ $($cur.dmDisplayFrequency) Hz"
    if ($best -and ($best.dmPelsWidth -ne $cur.dmPelsWidth -or $best.dmPelsHeight -ne $cur.dmPelsHeight -or $best.dmDisplayFrequency -ne $cur.dmDisplayFrequency)) {
        $best.dmFields = 0x80000 -bor 0x100000 -bor 0x400000   # width, height, refresh
        $r = [DxDisp]::ChangeDisplaySettingsEx($dd.Name, [ref]$best, [IntPtr]::Zero, 1, [IntPtr]::Zero)   # 1 = keep it after restart
        Say ("{0}: {1}  ->  {2}x{3} @ {4} Hz {5}" -f $dd.Str, $was, $best.dmPelsWidth, $best.dmPelsHeight, $best.dmDisplayFrequency, $(if ($r -eq 0) { '(done)' } else { "(Windows said $r)" })) 'Green'
    } else { Say "$($dd.Str): $was (already right)" 'Green' }
    $dd.cb = [Runtime.InteropServices.Marshal]::SizeOf($dd)
}
# ---- the spanned DUSTEX wallpaper
try {
    $wp = (Get-ItemProperty 'HKCU:\Control Panel\Desktop').Wallpaper
    Set-ItemProperty 'HKCU:\Control Panel\Desktop' WallpaperStyle '22'; Set-ItemProperty 'HKCU:\Control Panel\Desktop' TileWallpaper '0'
    Add-Type 'using System.Runtime.InteropServices; public static class DxWp { [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int SystemParametersInfo(int a, int b, string c, int d); }'
    [void][DxWp]::SystemParametersInfo(20, 0, $wp, 3); Say 'Wallpaper re-spanned across both screens.' 'Green'
} catch {}
Say "`nIf anything still looks off (HDR, colour, scaling), tell Claude what you see. Restart the PC so every widget re-docks." 'Yellow'
Read-Host "`nPress Enter to close"
