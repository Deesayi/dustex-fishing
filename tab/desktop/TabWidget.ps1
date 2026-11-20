<#
  DUSTEX | TAB - a guitar tablature builder docked under the Fishing panel on the right screen.
  Click a fret on the neck to write it at the cursor, drag notes on the tab to move them, add techniques with the
  buttons (or keys - press KEYS in the widget), then SAVE (your tab) or SAVE PDF / PRINT.
  LISTEN writes the notes as you play: plug the Spark 2 into the PC by USB and pick it under the gear button.
  Everything lives in this folder: TabWidget.ps1, the app\ folder, your saved tabs (*.dxtab) and the PDFs.
  The browser engine's cache is kept outside OneDrive, in %LOCALAPPDATA%\DUSTEX\TabWidget.
  Uses Microsoft WebView2 from C:\Tools\PCTuneAgent\widget\webview2 (installed with the YouTube widget).
  Right-click an empty spot (or the title bar area) for Reload / Open folder / iPad link / Close.
  iPad link: on the iPad open http://<this PC>:8790 in Safari (Share > Add to Home Screen makes it an app) and type the
  6-digit code once. The iPad shows this running studio live and your touches play it; all the sound, the guitar input and
  the listening stay on this PC. (One-time setup: run "Set up iPad Link.cmd" in this folder.)
#>
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    Start-Process powershell.exe -ArgumentList "-NoProfile -STA -File `"$PSCommandPath`"" -WindowStyle Minimized
    return
}
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -like '*TabWidget.ps1*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

$here = Split-Path -Parent $PSCommandPath                        # ...\Dashboard\Tab Widget
$appDir = Join-Path $here 'app'
$tools = 'C:\Tools\PCTuneAgent'
$logPath = Join-Path $here 'tab-widget.log'
function Write-Log([string]$msg) { try { Add-Content $logPath ("{0}  {1}" -f (Get-Date -Format s), $msg) } catch {} }

# shortcuts: one in the Dashboard folder, and one in Windows' Startup folder so the widget opens at sign-in (like the other widgets)
try {
    $ws = New-Object -ComObject WScript.Shell
    foreach ($lnk in @((Join-Path (Split-Path -Parent $here) 'Tab Widget.lnk'), (Join-Path ([Environment]::GetFolderPath('Startup')) 'DUSTEX Tab.lnk'))) {
        if (-not (Test-Path $lnk)) {
            $sc = $ws.CreateShortcut($lnk)
            $sc.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"; $sc.Arguments = "-NoProfile -STA -WindowStyle Hidden -File `"$PSCommandPath`""
            $sc.WorkingDirectory = $here; $sc.WindowStyle = 7; $sc.IconLocation = "$env:SystemRoot\System32\imageres.dll,103"; $sc.Description = 'DUSTEX guitar tab builder'; $sc.Save()
            Write-Log "made shortcut $lnk"
        }
    }
} catch { Write-Log "shortcut: $($_.Exception.Message)" }

# ------------------------------------------------------------------ WebView2
$wvDir = Join-Path $tools 'widget\webview2'
if (-not (Test-Path (Join-Path $wvDir 'Microsoft.Web.WebView2.Wpf.dll'))) {
    [System.Windows.MessageBox]::Show("The tab widget needs WebView2. Run:`n`n$tools\tools\Setup-YouTubeWidget.ps1", 'DUSTEX Tab') | Out-Null; return
}
Add-Type -Path (Join-Path $wvDir 'Microsoft.Web.WebView2.Core.dll')
Add-Type -Path (Join-Path $wvDir 'Microsoft.Web.WebView2.Wpf.dll')
try { [Microsoft.Web.WebView2.Core.CoreWebView2Environment]::SetLoaderDllFolderPath($wvDir) } catch { Write-Log "loader path: $($_.Exception.Message)" }
$useComp = [bool]('Microsoft.Web.WebView2.Wpf.WebView2CompositionControl' -as [type])

# ------------------------------------------------------------------ the Tab port under the Fishing panel
function Get-WallpaperMap {
    $vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $sc = [math]::Max($vs.Width / 6880.0, $vs.Height / 1440.0)
    return @{ S = $sc; X = $vs.Left + ($vs.Width - 6880 * $sc) / 2; Y = $vs.Top + ($vs.Height - 1440 * $sc) / 2 }
}
function Get-Port {
    foreach ($pp in (Join-Path $tools 'blender\renders\ports.json'), (Join-Path $tools 'widget\ports.json')) {
        if (Test-Path $pp) { try { $j = Get-Content $pp -Raw | ConvertFrom-Json; if ($j.PSObject.Properties['Tab']) { return $j.Tab } } catch {} }
    }
    return [pscustomobject]@{ X0 = 3521; Y0 = 900; X1 = 5096; Y1 = 1366 }
}
$port = Get-Port
$PW = ([double]$port.X1 - $port.X0) - 4; $PH = ([double]$port.Y1 - $port.Y0) - 4

# the steel DUSTEX logo for the header
$logo = Join-Path $appDir 'logo.png'
if (-not (Test-Path $logo)) { try { Copy-Item (Join-Path $tools 'widget\claude_logo_steel.png') $logo -ErrorAction Stop } catch {} }

$wvType = if ($useComp) { 'Microsoft.Web.WebView2.Wpf.WebView2CompositionControl' } else { 'Microsoft.Web.WebView2.Wpf.WebView2' }
$props = New-Object Microsoft.Web.WebView2.Wpf.CoreWebView2CreationProperties
$props.UserDataFolder = Join-Path $env:LOCALAPPDATA 'DUSTEX\TabWidget'
$view = New-Object $wvType; $view.CreationProperties = $props
try { $view.DefaultBackgroundColor = [System.Drawing.Color]::Transparent } catch {}
$view.Width = $PW; $view.Height = $PH
$holder = New-Object Windows.Controls.Canvas; $holder.Width = $PW; $holder.Height = $PH; [void]$holder.Children.Add($view)
$wnd = New-Object Windows.Window
$wnd.WindowStyle = 'None'; $wnd.ResizeMode = 'NoResize'; $wnd.ShowInTaskbar = $false; $wnd.Title = 'DUSTEX Tab'; $wnd.Content = $holder
if ($useComp) { $wnd.AllowsTransparency = $true; $wnd.Background = [Windows.Media.Brushes]::Transparent }
else { $wnd.Background = (New-Object Windows.Media.SolidColorBrush([Windows.Media.Color]::FromRgb(16, 17, 20))) }
function Dock-Window {   # into the Tab port on the wallpaper
    $m = [Windows.PresentationSource]::FromVisual($wnd).CompositionTarget.TransformFromDevice
    $wm = Get-WallpaperMap
    $view.Width = $PW; $view.Height = $PH; $holder.Width = $PW; $holder.Height = $PH
    $holder.LayoutTransform = New-Object Windows.Media.ScaleTransform(($wm.S * $m.M11), ($wm.S * $m.M22))
    $wnd.Width = $PW * $wm.S * $m.M11; $wnd.Height = $PH * $wm.S * $m.M22
    $wnd.Left = ($wm.X + ([double]$port.X0 + 2) * $wm.S) * $m.M11; $wnd.Top = ($wm.Y + ([double]$port.Y0 + 2) * $wm.S) * $m.M22
    $wnd.Topmost = $false
}
function Fill-Screen {   # full screen on the monitor the widget sits on
    $m = [Windows.PresentationSource]::FromVisual($wnd).CompositionTarget.TransformFromDevice
    $cx = [int](($wnd.Left + $wnd.Width / 2) / $m.M11); $cy = [int](($wnd.Top + $wnd.Height / 2) / $m.M22)
    $scrn = [System.Windows.Forms.Screen]::FromPoint((New-Object System.Drawing.Point($cx, $cy))); $bnd = $scrn.Bounds
    $fw = $bnd.Width * $m.M11; $fh = $bnd.Height * $m.M22
    $holder.LayoutTransform = New-Object Windows.Media.ScaleTransform(1, 1)
    $view.Width = $fw; $view.Height = $fh; $holder.Width = $fw; $holder.Height = $fh
    $wnd.Left = $bnd.Left * $m.M11; $wnd.Top = $bnd.Top * $m.M22; $wnd.Width = $fw; $wnd.Height = $fh
    $wnd.Topmost = $true; [void]$wnd.Activate()
}
function Dock-Remote {   # iPad connected: the page is laid out at the iPad's size and shown scaled to fit the port, centred
    $m = [Windows.PresentationSource]::FromVisual($wnd).CompositionTarget.TransformFromDevice
    $wm = Get-WallpaperMap
    $w = [double]$script:rW; $h = [double]$script:rH
    $k = [math]::Min($PW * $wm.S / $w, $PH * $wm.S / $h)                  # device pixels per page pixel
    $view.Width = $w; $view.Height = $h; $holder.Width = $w; $holder.Height = $h
    $holder.LayoutTransform = New-Object Windows.Media.ScaleTransform(($k * $m.M11), ($k * $m.M22))
    $wnd.Width = $w * $k * $m.M11; $wnd.Height = $h * $k * $m.M22
    $wnd.Left = ($wm.X + ([double]$port.X0 + 2) * $wm.S + ($PW * $wm.S - $w * $k) / 2) * $m.M11
    $wnd.Top = ($wm.Y + ([double]$port.Y0 + 2) * $wm.S + ($PH * $wm.S - $h * $k) / 2) * $m.M22
    $wnd.Topmost = $false
}
function Apply-Layout { if ($script:isFull) { Fill-Screen } elseif ($script:rOn) { Dock-Remote } else { Dock-Window } }
$script:isFull = $false; $script:rOn = $false; $script:rW = 1180; $script:rH = 820
$wnd.Add_SourceInitialized({ Dock-Window })

# ------------------------------------------------------------------ iPad link: a small web server on the home network
# The server runs on its own thread (a runspace) and only moves bytes: JPEG frames of this page out, touches and keys in.
# The page is captured with the browser engine's own screencast (it sends a frame only when something changes), and touches
# are played into the page as real mouse input, so the iPad drives exactly what is running here.
$RPORT = 8790
$rDir = Join-Path $env:LOCALAPPDATA 'DUSTEX\TabWidget'; if (-not (Test-Path $rDir)) { [void](New-Item -ItemType Directory -Force -Path $rDir) }
$pinFile = Join-Path $rDir 'ipad-code.txt'
if (-not (Test-Path $pinFile)) { $rb = New-Object byte[] 4; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($rb); Set-Content $pinFile ('{0:D6}' -f ([BitConverter]::ToUInt32($rb, 0) % 1000000)) -Encoding ASCII }
$RM = [hashtable]::Synchronized(@{
    run = $true; port = $RPORT; pin = (Get-Content $pinFile -Raw).Trim(); page = (Join-Path $appDir 'remote.html'); icon = (Join-Path $appDir 'icon-180.png')
    inbox = New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]'; outbox = New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]'
    frame = $null; frameNo = 0; size = ''; client = $false; err = ''; log = $logPath
})
$rServer = {
    param($RM)
    function L($t) { try { Add-Content $RM.log ("{0}  ipad: {1}" -f (Get-Date -Format s), $t) } catch {} }
    $none = [Threading.CancellationToken]::None; $utf = New-Object Text.UTF8Encoding($false)
    $lis = New-Object Net.HttpListener; $lis.Prefixes.Add("http://+:$($RM.port)/")
    try { $lis.Start() } catch { $RM.err = $_.Exception.Message; L "server did not start: $($RM.err) (run Set up iPad Link.cmd once)"; return }
    L "listening on port $($RM.port)"
    $cx = $lis.GetContextAsync(); $ws = $null; $rx = $null; $sizeSent = ''; $buf = New-Object byte[] 65536; $acc = New-Object IO.MemoryStream; $sent = 0
    function Drop { if ($ws) { try { $ws.Abort(); $ws.Dispose() } catch {} }; Set-Variable ws $null -Scope 1; Set-Variable rx $null -Scope 1; $RM.client = $false; $RM.inbox.Enqueue('{"t":"close"}'); L 'iPad disconnected' }
    while ($RM.run) {
        $busy = $false
        if ($cx.IsCompleted) {
            $busy = $true
            try { $ctx = $cx.Result } catch { $ctx = $null }
            $cx = $lis.GetContextAsync()
            if ($ctx) { try {
                $rq = $ctx.Request; $path = $rq.Url.AbsolutePath; $ok = ($rq.QueryString['code'] -eq $RM.pin)
                if ($path -eq '/ws' -and $rq.IsWebSocketRequest) {
                    if (-not $ok) { $ctx.Response.StatusCode = 403; $ctx.Response.Close() }
                    else {
                        if ($ws) { Drop }                                   # the newest iPad takes over
                        $acc0 = $ctx.GetType().GetMethod('AcceptWebSocketAsync', [Type[]]@([string])); $ws = $acc0.Invoke($ctx, [object[]]@($null)).Result.WebSocket;   # a true null: PowerShell turns $null into "" for string parameters
                        $rx = $null; $sent = 0; $sizeSent = ''; $RM.client = $true
                        $RM.inbox.Enqueue('{"t":"open"}'); L "iPad connected from $($rq.RemoteEndPoint.Address)"
                    }
                } else {
                    $rs = $ctx.Response; $rs.Headers['Cache-Control'] = 'no-store'
                    switch ($path) {
                        { $_ -in '/', '/remote.html' } { $b = [IO.File]::ReadAllBytes($RM.page); $rs.ContentType = 'text/html; charset=utf-8' }
                        '/icon.png' { $b = [IO.File]::ReadAllBytes($RM.icon); $rs.ContentType = 'image/png' }
                        '/check' { $b = $utf.GetBytes($(if ($ok) { 'ok' } else { 'no' })); $rs.ContentType = 'text/plain'; if (-not $ok) { Start-Sleep -Milliseconds 600 } }
                        default { $b = $utf.GetBytes('not found'); $rs.StatusCode = 404 }
                    }
                    $rs.ContentLength64 = $b.Length; $rs.OutputStream.Write($b, 0, $b.Length); $rs.Close()
                }
            } catch { L "request: $($_.Exception.Message)"; try { $ctx.Response.Abort() } catch {} } }
        }
        if ($ws) {
            try {
                if ($ws.State -ne [Net.WebSockets.WebSocketState]::Open) { Drop }
                else {
                    if (-not $rx) { $rx = $ws.ReceiveAsync([ArraySegment[byte]]::new($buf), $none) }
                    if ($rx.IsCompleted) {
                        $busy = $true
                        if ($rx.IsFaulted -or $rx.IsCanceled) { Drop }
                        else {
                            $r = $rx.Result; $rx = $null
                            if ($r.MessageType -eq [Net.WebSockets.WebSocketMessageType]::Close) { Drop }
                            else { $acc.Write($buf, 0, $r.Count); if ($r.EndOfMessage) { $RM.inbox.Enqueue($utf.GetString($acc.ToArray())); $acc.SetLength(0) } }
                        }
                    }
                    if ($ws) {
                        $o = $null
                        while ($RM.outbox.TryDequeue([ref]$o)) { $tb = $utf.GetBytes($o); [void]$ws.SendAsync([ArraySegment[byte]]::new($tb), [Net.WebSockets.WebSocketMessageType]::Text, $true, $none).Wait(2000) }
                        $fn = $RM.frameNo
                        if ($fn -ne $sent -and $RM.frame) {
                            $fb = $RM.frame; $sent = $fn; $busy = $true
                            $sz = $RM.size
                            if ($sz -and $sz -ne $sizeSent) { $sizeSent = $sz; $sb = $utf.GetBytes($sz); [void]$ws.SendAsync([ArraySegment[byte]]::new($sb), [Net.WebSockets.WebSocketMessageType]::Text, $true, $none).Wait(2000) }
                            if (-not $ws.SendAsync([ArraySegment[byte]]::new($fb), [Net.WebSockets.WebSocketMessageType]::Binary, $true, $none).Wait(4000)) { Drop }
                        }
                    }
                }
            } catch { L "socket: $($_.Exception.Message)"; Drop }
        }
        if (-not $busy) { Start-Sleep -Milliseconds 4 }
    }
    if ($ws) { Drop }
    try { $lis.Stop(); $lis.Close() } catch {}
}
$rRs = [runspacefactory]::CreateRunspace(); $rRs.Open()
$rPs = [powershell]::Create(); $rPs.Runspace = $rRs; [void]$rPs.AddScript($rServer).AddArgument($RM); $rHandle = $rPs.BeginInvoke()

$script:rDown = $false
$script:cdpTasks = New-Object System.Collections.ArrayList; $script:cdpSeen = @{}
function Cdp([string]$method, $obj) {
    try {
        $json = $obj | ConvertTo-Json -Compress -Depth 4
        $tk = $view.CoreWebView2.CallDevToolsProtocolMethodAsync($method, $json)
        if (-not $script:cdpSeen.ContainsKey($method)) { $script:cdpSeen[$method] = 1; Write-Log "cdp first $method $json" }
        if ($script:cdpTasks.Count -lt 400) { [void]$script:cdpTasks.Add(@($method, $tk)) }
    } catch { Write-Log "cdp $method : $($_.Exception.Message)" }
}
function Check-Cdp {   # report any DevTools call the browser refused (once per kind)
    for ($i = $script:cdpTasks.Count - 1; $i -ge 0; $i--) {
        $e = $script:cdpTasks[$i]; $tk = $e[1]
        if ($tk.IsCompleted) {
            if ($tk.IsFaulted -and -not $script:cdpSeen.ContainsKey('x' + $e[0])) { $script:cdpSeen['x' + $e[0]] = 1; Write-Log "cdp failed $($e[0]): $($tk.Exception.InnerException.Message)" }
            $script:cdpTasks.RemoveAt($i)
        }
    }
}
function Remote-Start($w, $h, $dpr) {
    # the widget's page takes the iPad's shape (so nothing is cut off on either screen); the page itself is never bent
    $script:rW = [int][math]::Max([double]480, [math]::Min([double]2000, [double]$w)); $script:rH = [int][math]::Max([double]360, [math]::Min([double]2000, [double]$h))
    $dsf = [math]::Round([math]::Max([double]1.0, [math]::Min([double]1.5, [double]$dpr)), 2)            # sharp on the iPad, light on the network
    $script:rOn = $true
    Apply-Layout
    Cdp 'Emulation.setDeviceMetricsOverride' @{ width = 0; height = 0; deviceScaleFactor = $dsf; mobile = $false }   # 0 = keep the real size, only render sharper
    Cdp 'Page.startScreencast' @{ format = 'jpeg'; quality = 72; maxWidth = 2400; maxHeight = 1800; everyNthFrame = 2 }
    Reply @{ type = 'fullscreen'; on = $true }                                             # the full studio layout
    $tick.Interval = [TimeSpan]::FromMilliseconds(12); Write-Log "ipad view $($script:rW)x$($script:rH) @$dsf"
}
function Remote-Stop {
    if (-not $script:rOn) { return }
    if ($script:rDown) { Cdp 'Input.dispatchMouseEvent' @{ type = 'mouseReleased'; x = 1; y = 1; button = 'left'; buttons = 0; clickCount = 1 } }
    $script:rOn = $false; $script:rDown = $false
    Cdp 'Page.stopScreencast' @{}; Cdp 'Emulation.clearDeviceMetricsOverride' @{}
    $RM.frame = $null; Apply-Layout
    Reply @{ type = 'fullscreen'; on = $script:isFull }
    $tick.Interval = [TimeSpan]::FromMilliseconds(250); Write-Log 'ipad view closed'
}
$KEYCODES = @{ Backspace = 8; Tab = 9; Enter = 13; Escape = 27; ' ' = 32; ArrowLeft = 37; ArrowUp = 38; ArrowRight = 39; ArrowDown = 40; Delete = 46 }
function Remote-Input([string]$raw) {
    $m = $raw | ConvertFrom-Json
    switch ($m.t) {
        'hello' { Remote-Start $m.w $m.h $m.dpr }
        'close' { Remote-Stop }
        'd' { $script:rDown = $true; Cdp 'Input.dispatchMouseEvent' @{ type = 'mousePressed'; x = [double]$m.x; y = [double]$m.y; button = 'left'; buttons = 1; clickCount = [int]$(if ($m.n) { $m.n } else { 1 }) } }
        'm' { Cdp 'Input.dispatchMouseEvent' @{ type = 'mouseMoved'; x = [double]$m.x; y = [double]$m.y; button = $(if ($script:rDown) { 'left' } else { 'none' }); buttons = [int]$script:rDown } }
        'u' { $script:rDown = $false; Cdp 'Input.dispatchMouseEvent' @{ type = 'mouseReleased'; x = [double]$m.x; y = [double]$m.y; button = 'left'; buttons = 0; clickCount = [int]$(if ($m.n) { $m.n } else { 1 }) } }
        'w' { Cdp 'Input.dispatchMouseEvent' @{ type = 'mouseWheel'; x = [double]$m.x; y = [double]$m.y; deltaX = [double]$m.dx; deltaY = [double]$m.dy } }
        'text' { Cdp 'Input.insertText' @{ text = [string]$m.s } }
        'key' {
            $k = [string]$m.k; $vk = if ($KEYCODES.ContainsKey($k)) { $KEYCODES[$k] } else { 0 }
            foreach ($ty in 'rawKeyDown', 'keyUp') { Cdp 'Input.dispatchKeyEvent' @{ type = $ty; key = $k; code = $(if ($k -eq ' ') { 'Space' } else { $k }); windowsVirtualKeyCode = $vk } }
        }
    }
}
function Show-iPadLink {
    $ips = @([Net.Dns]::GetHostAddresses([Net.Dns]::GetHostName()) | Where-Object { $_.AddressFamily -eq 'InterNetwork' -and "$_" -notlike '169.254.*' } | ForEach-Object { "http://$($_):$RPORT" })
    $t = "On the iPad, open Safari and go to:`n`n    http://$($env:COMPUTERNAME.ToLower()).local:$RPORT`n    or  $($ips -join '   or   ')`n`nType this code once:   $($RM.pin)`n`nThen Share > Add to Home Screen to keep it as an app."
    if ($RM.err) { $t += "`n`nThe link isn't running yet: $($RM.err)`nRun 'Set up iPad Link.cmd' in the Tab Widget folder once, then restart the widget." }
    [System.Windows.MessageBox]::Show($t, 'DUSTEX Tab - iPad link') | Out-Null
}

# ------------------------------------------------------------------ messages from the page: save, open, list, PDF, print
function Reply($obj) { try { $view.CoreWebView2.PostWebMessageAsJson(($obj | ConvertTo-Json -Compress -Depth 4)) } catch { Write-Log "reply: $($_.Exception.Message)" } }
function Safe-Name([string]$n, [string]$ext) {
    $n = [IO.Path]::GetFileName("$n"); foreach ($ch in [IO.Path]::GetInvalidFileNameChars()) { $n = $n.Replace([string]$ch, '') }
    if (-not $n.EndsWith($ext)) { $n += $ext }; if ($n -eq $ext) { $n = 'Untitled tab' + $ext }; return $n
}
$utf8 = New-Object Text.UTF8Encoding($false)
$script:pdfTask = $null; $script:pdfName = ''
function On-Message($raw) {
    $msg = $raw | ConvertFrom-Json
    switch ($msg.cmd) {
        'hello' {
            if ($script:rOn) { Reply @{ type = 'fullscreen'; on = $true } }
            $as = Join-Path $appDir '_autosave.dxtab'
            if (Test-Path $as) { Reply @{ type = 'autosave'; json = [IO.File]::ReadAllText($as, $utf8) } }
        }
        'autosave' { [IO.File]::WriteAllText((Join-Path $appDir '_autosave.dxtab'), [string]$msg.json, $utf8) }
        'save' {
            $nm = Safe-Name $msg.name '.dxtab'
            [IO.File]::WriteAllText((Join-Path $here $nm), [string]$msg.json, $utf8)
            Write-Log "saved $nm"; Reply @{ type = 'saved'; name = $nm }
        }
        'list' {
            $files = @(Get-ChildItem $here -Filter '*.dxtab' -File | Sort-Object LastWriteTime -Descending | ForEach-Object { $_.Name })
            Reply @{ type = 'list'; files = $files }
        }
        'open' {
            $nm = Safe-Name $msg.name '.dxtab'; $fp = Join-Path $here $nm
            if (Test-Path $fp) { Reply @{ type = 'opened'; name = $nm; json = [IO.File]::ReadAllText($fp, $utf8) } } else { Reply @{ type = 'error'; message = "$nm not found" } }
        }
        'pdf' {
            $nm = Safe-Name $msg.name '.pdf'; $fp = Join-Path $here $nm; $script:pdfName = $nm
            $ps = $view.CoreWebView2.Environment.CreatePrintSettings()
            $ps.Orientation = [Microsoft.Web.WebView2.Core.CoreWebView2PrintOrientation]::Portrait
            $ps.PageWidth = 8.5; $ps.PageHeight = 11; $ps.MarginTop = 0.5; $ps.MarginBottom = 0.5; $ps.MarginLeft = 0.5; $ps.MarginRight = 0.5
            $ps.ShouldPrintBackgrounds = $true; $ps.ShouldPrintHeaderAndFooter = $false
            $script:pdfTask = $view.CoreWebView2.PrintToPdfAsync($fp, $ps)
        }
        'print' {
            try { $view.CoreWebView2.ShowPrintUI([Microsoft.Web.WebView2.Core.CoreWebView2PrintDialogKind]::System) }
            catch { [void]$view.CoreWebView2.ExecuteScriptAsync('window.print()') }
        }
        'folder' { Start-Process explorer.exe "`"$here`"" }
        'fullscreen' {   # the page asks to fill the screen (full-page layout) or go back to the dock
            $script:isFull = [bool]$msg.on
            Apply-Layout                                                       # with the iPad on, leaving full screen goes back to the iPad-shaped dock
            Write-Log "fullscreen $($script:isFull)"; Reply @{ type = 'fullscreen'; on = ($script:isFull -or $script:rOn) }
        }
        'take' {   # chords + notes mode: keep the audio and what was detected, so a take can be checked later
            $tkDir = Join-Path $here 'Takes'; if (-not (Test-Path $tkDir)) { [void](New-Item -ItemType Directory -Path $tkDir) }
            $tkBase = [IO.Path]::GetFileNameWithoutExtension((Safe-Name $msg.name '.wav'))
            [IO.File]::WriteAllBytes((Join-Path $tkDir ($tkBase + '.wav')), [Convert]::FromBase64String([string]$msg.wav))
            [IO.File]::WriteAllText((Join-Path $tkDir ($tkBase + '.json')), [string]$msg.json, $utf8)
            $tkOld = @(Get-ChildItem $tkDir -Filter '*.wav' -File | Sort-Object LastWriteTime -Descending | Select-Object -Skip 30)
            foreach ($tkF in $tkOld) { Remove-Item -LiteralPath $tkF.FullName -ErrorAction SilentlyContinue; Remove-Item -LiteralPath ([IO.Path]::ChangeExtension($tkF.FullName, '.json')) -ErrorAction SilentlyContinue }
            Write-Log "take saved $tkBase"; Reply @{ type = 'takeSaved'; name = $tkBase }
        }
    }
}

$view.Add_CoreWebView2InitializationCompleted({ param($sx, $ev)
    if (-not $ev.IsSuccess) { Write-Log "init failed: $($ev.InitializationException.Message)"; return }
    try {
        $core = $view.CoreWebView2
        $core.Settings.IsStatusBarEnabled = $false; $core.Settings.IsZoomControlEnabled = $false
        $core.SetVirtualHostNameToFolderMapping('tab.dustex', $appDir, [Microsoft.Web.WebView2.Core.CoreWebView2HostResourceAccessKind]::Allow)
        # LISTEN uses the guitar input (the Spark 2 over USB): let the tab page open it without asking each time
        $core.Add_PermissionRequested({ param($s2, $e2) if ("$($e2.PermissionKind)" -eq 'Microphone' -and "$($e2.Uri)" -like 'https://tab.dustex/*') { $e2.State = 'Allow'; Write-Log 'audio input allowed' } })
        $core.Add_WebMessageReceived({ param($s2, $e2) try { On-Message $e2.WebMessageAsJson } catch { Write-Log "message: $($_.Exception.Message)"; Reply @{ type = 'error'; message = $_.Exception.Message } } })
        try {   # right-click: Reload / Open folder / Close (copy and paste stay for the title fields)
            $env2 = $core.Environment
            $script:miReload = $env2.CreateContextMenuItem('Reload', $null, [Microsoft.Web.WebView2.Core.CoreWebView2ContextMenuItemKind]::Command)
            $script:miFolder = $env2.CreateContextMenuItem('Open the Tab Widget folder', $null, [Microsoft.Web.WebView2.Core.CoreWebView2ContextMenuItemKind]::Command)
            $script:miClose = $env2.CreateContextMenuItem('Close', $null, [Microsoft.Web.WebView2.Core.CoreWebView2ContextMenuItemKind]::Command)
            $script:miIpad = $env2.CreateContextMenuItem('iPad link...', $null, [Microsoft.Web.WebView2.Core.CoreWebView2ContextMenuItemKind]::Command)
            $script:miIpad.Add_CustomItemSelected({ $wnd.Dispatcher.BeginInvoke([Action] { Show-iPadLink }) | Out-Null })
            $script:miReload.Add_CustomItemSelected({ $view.CoreWebView2.Reload() })
            $script:miFolder.Add_CustomItemSelected({ Start-Process explorer.exe "`"$here`"" })
            $script:miClose.Add_CustomItemSelected({ $wnd.Dispatcher.BeginInvoke([Action] { $wnd.Close() }) | Out-Null })
            $core.Add_ContextMenuRequested({ param($s2, $e2)
                $keep = @($e2.MenuItems | Where-Object { $_.Name -in 'copy', 'paste', 'cut', 'selectAll' })
                $e2.MenuItems.Clear(); foreach ($k in $keep) { $e2.MenuItems.Add($k) }
                foreach ($mi in $script:miReload, $script:miFolder, $script:miIpad, $script:miClose) { $e2.MenuItems.Add($mi) } })
        } catch { Write-Log "context menu: $($_.Exception.Message)" }
        # iPad link: frames of the page go out as they're painted
        try {
            [void]$core.CallDevToolsProtocolMethodAsync('Page.enable', '{}')
            $script:scRecv = $core.GetDevToolsProtocolEventReceiver('Page.screencastFrame')
            $script:scRecv.add_DevToolsProtocolEventReceived({ param($s2, $e2)
                try {
                    $j = $e2.ParameterObjectAsJson
                    $sid = [regex]::Match($j, '"sessionId":(\d+)').Groups[1].Value
                    [void]$view.CoreWebView2.CallDevToolsProtocolMethodAsync('Page.screencastFrameAck', "{`"sessionId`":$sid}")
                    if ($script:rOn) {
                        $i0 = $j.IndexOf('"data":"') + 8; $i1 = $j.IndexOf('"', $i0)
                        $mw = [regex]::Match($j, '"deviceWidth":([\d.]+)').Groups[1].Value; $mh = [regex]::Match($j, '"deviceHeight":([\d.]+)').Groups[1].Value
                        if ($mw) { $RM.size = '{"t":"size","w":' + $mw + ',"h":' + $mh + '}' }
                        $RM.frame = [Convert]::FromBase64String($j.Substring($i0, $i1 - $i0)); $RM.frameNo++
                    }
                } catch { Write-Log "frame: $($_.Exception.Message)" }
            })
        } catch { Write-Log "screencast: $($_.Exception.Message)" }
        $core.Navigate('https://tab.dustex/index.html')
    } catch { Write-Log "setup: $($_.Exception.Message)" }
})

# PDF finishes in the background: tell the page when it's written
$tick = New-Object Windows.Threading.DispatcherTimer; $tick.Interval = [TimeSpan]::FromMilliseconds(250)
$tick.Add_Tick({
    $rq = $null; $rn = 0
    while ($rn -lt 200 -and $RM.inbox.TryDequeue([ref]$rq)) { $rn++; try { Remote-Input $rq } catch { Write-Log "ipad input: $($_.Exception.Message) [$rq]" } }
    if ($script:cdpTasks.Count) { Check-Cdp }
    if ($script:pdfTask -and $script:pdfTask.IsCompleted) {
        $tk = $script:pdfTask; $script:pdfTask = $null
        if ($tk.IsFaulted) { Write-Log "pdf: $($tk.Exception.InnerException.Message)"; Reply @{ type = 'pdf'; ok = $false; name = $script:pdfName; error = $tk.Exception.InnerException.Message } }
        else { Write-Log "pdf $($script:pdfName) ok=$($tk.Result)"; Reply @{ type = 'pdf'; ok = [bool]$tk.Result; name = $script:pdfName } }
    }
})
$wnd.Add_ContentRendered({ try { [void]$view.EnsureCoreWebView2Async($null) } catch { Write-Log "start: $($_.Exception.Message)" }; $tick.Start() })
$wnd.Add_Closing({ $tick.Stop(); $RM.run = $false; try { [void]$rHandle.AsyncWaitHandle.WaitOne(1500); $rPs.Dispose(); $rRs.Close() } catch {}; try { $view.Dispose() } catch {} })
Write-Log "start  composition=$useComp  port=$($port.X0),$($port.Y0),$($port.X1),$($port.Y1)"
[void]$wnd.ShowDialog()
