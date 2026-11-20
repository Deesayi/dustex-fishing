<#
  DUSTEX | one-time setup for the Tab Creator Studio iPad link (no extra programs).
  Lets the Tab widget answer on port 8790 of your home network and lets that port through the Windows firewall
  (home/private networks only). Then restarts the Tab widget and shows the address and code for the iPad.
#>
param([switch]$Elevated, [string]$ForUser = '')
$port = 8790
if (-not $Elevated) {
    $me = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Host "`nDUSTEX  |  iPad link for Tab Creator Studio`n" -ForegroundColor Yellow
    Write-Host 'Windows will ask to allow the setup (it opens the network port). Say Yes.' -ForegroundColor Cyan
    try { Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Elevated -ForUser `"$me`"" }
    catch { Write-Host 'The setup was not allowed, so nothing changed.' -ForegroundColor Red; Read-Host 'Press Enter to close'; return }
    # restart the Tab widget (as you, not as administrator) so it opens the link
    $tw = Join-Path (Split-Path -Parent $PSCommandPath) 'TabWidget.ps1'
    Start-Process powershell.exe -ArgumentList "-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$tw`"" -WindowStyle Hidden
    $pinFile = Join-Path $env:LOCALAPPDATA 'DUSTEX\TabWidget\ipad-code.txt'
    for ($i = 0; $i -lt 20 -and -not (Test-Path $pinFile); $i++) { Start-Sleep -Milliseconds 500 }
    $ips = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } | ForEach-Object { "http://$($_.IPAddress):$port" })
    Write-Host "`nOn the iPad, open Safari and go to:" -ForegroundColor Yellow
    Write-Host "    http://$($env:COMPUTERNAME.ToLower()).local:$port" -ForegroundColor White
    foreach ($u in $ips) { Write-Host "    or  $u" -ForegroundColor White }
    if (Test-Path $pinFile) { Write-Host "`nCode (type it once on the iPad):  $((Get-Content $pinFile -Raw).Trim())" -ForegroundColor Yellow }
    Write-Host "`nThen tap Share > Add to Home Screen to keep it as an app icon." -ForegroundColor Gray
    Write-Host 'Right-click the Tab widget > iPad link... shows this again any time.' -ForegroundColor Gray
    Read-Host "`nPress Enter to close"; return
}
# ---- the administrator part
try {
    & netsh http delete urlacl url="http://+:$port/" | Out-Null
    $r = & netsh http add urlacl url="http://+:$port/" user="$ForUser"
    Write-Host ($r -join ' ')
    Get-NetFirewallRule -DisplayName 'DUSTEX Tab iPad link' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    New-NetFirewallRule -DisplayName 'DUSTEX Tab iPad link' -Direction Inbound -Protocol TCP -LocalPort $port -Profile Private -Action Allow | Out-Null
    Write-Host 'Port 8790 opened for home (private) networks.' -ForegroundColor Green
    $pub = @(Get-NetConnectionProfile -ErrorAction SilentlyContinue | Where-Object { $_.NetworkCategory -eq 'Public' })
    foreach ($n in $pub) {
        $a = Read-Host "Windows has your network '$($n.Name)' set to Public, which blocks the iPad. Set it to Private (home)? (Y/N)"
        if ($a -match '^[Yy]') { Set-NetConnectionProfile -InterfaceIndex $n.InterfaceIndex -NetworkCategory Private; Write-Host "'$($n.Name)' is now Private." -ForegroundColor Green }
    }
} catch { Write-Host $_.Exception.Message -ForegroundColor Red; Read-Host 'Press Enter to close' }
