$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path $AppDir "logs"
$LogFile = Join-Path $LogDir "solodrop.log"
$StartScript = Join-Path $AppDir "Start SoloDrop.cmd"
$TrayIconPath = Join-Path $AppDir "static\icons\tray-icon.ico"
$Port = 8765
$ServerProcess = $null

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

function Get-SoloDropPid {
    $connection = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($connection) {
        return $connection.OwningProcess
    }

    return $null
}

function Test-SoloDropRunning {
    return [bool](Get-SoloDropPid)
}

function Start-SoloDrop {
    if (Test-SoloDropRunning) {
        return
    }

    $arguments = "/c `"`"$StartScript`" --quiet >> `"$LogFile`" 2>&1`""
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = "cmd.exe"
    $info.Arguments = $arguments
    $info.WorkingDirectory = $AppDir
    $info.CreateNoWindow = $true
    $info.UseShellExecute = $false
    $info.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden

    $script:ServerProcess = [System.Diagnostics.Process]::Start($info)
}

function Stop-SoloDrop {
    $serverPid = Get-SoloDropPid
    if ($serverPid) {
        Stop-Process -Id $serverPid -Force -ErrorAction SilentlyContinue
    }
}

function Restart-SoloDrop {
    Stop-SoloDrop
    Start-Sleep -Seconds 1
    Start-SoloDrop
}

function Update-Tooltip {
    if (Test-SoloDropRunning) {
        $notifyIcon.Text = "SoloDrop is running on port $Port"
    } else {
        $notifyIcon.Text = "SoloDrop is stopped"
    }
}

$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
if (Test-Path $TrayIconPath) {
    $script:TrayIcon = New-Object System.Drawing.Icon $TrayIconPath
    $notifyIcon.Icon = $script:TrayIcon
} else {
    $notifyIcon.Icon = [System.Drawing.SystemIcons]::Application
}
$notifyIcon.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip

$openItem = $menu.Items.Add("Open SoloDrop")
$openItem.Add_Click({
    Start-Process "http://127.0.0.1:8765"
})

$folderItem = $menu.Items.Add("Open Folder")
$folderItem.Add_Click({
    Start-Process explorer.exe $AppDir
})

[void]$menu.Items.Add("-")

$restartItem = $menu.Items.Add("Restart")
$restartItem.Add_Click({
    Restart-SoloDrop
    Update-Tooltip
})

$stopItem = $menu.Items.Add("Stop")
$stopItem.Add_Click({
    Stop-SoloDrop
    Update-Tooltip
})

$exitItem = $menu.Items.Add("Exit")
$exitItem.Add_Click({
    Stop-SoloDrop
    $notifyIcon.Visible = $false
    if ($script:TrayIcon) { $script:TrayIcon.Dispose() }
    [System.Windows.Forms.Application]::Exit()
})

$notifyIcon.ContextMenuStrip = $menu
$notifyIcon.Add_DoubleClick({
    Start-Process "http://127.0.0.1:8765"
})

Start-SoloDrop
Update-Tooltip

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 5000
$timer.Add_Tick({ Update-Tooltip })
$timer.Start()

[System.Windows.Forms.Application]::Run()
