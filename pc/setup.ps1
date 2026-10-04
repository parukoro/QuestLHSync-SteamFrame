param(
    [ValidateSet('Install', 'Status', 'Remove')][string]$Action = 'Install',
    [string]$FrameHost = '',
    [string]$HeadsetSerial = '',
    [string]$DriverPath = ''
)
$ErrorActionPreference = 'Stop'

function Get-SteamVR {
    $pathsFile = Join-Path $env:LOCALAPPDATA 'openvr/openvrpaths.vrpath'
    if (!(Test-Path -LiteralPath $pathsFile)) { throw 'Run SteamVR once before using this installer.' }
    $paths = Get-Content -LiteralPath $pathsFile -Raw | ConvertFrom-Json
    foreach ($runtime in $paths.runtime) {
        $exe = Join-Path $runtime 'bin/win64/vrpathreg.exe'
        if (Test-Path -LiteralPath $exe) {
            return @{Exe = $exe; Settings = (Join-Path $paths.config[0] 'steamvr.vrsettings')}
        }
    }
    throw 'SteamVR runtime was not found.'
}

function Test-FrameLink([string]$Address) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $task = $client.ConnectAsync($Address, 47280)
        if (!$task.Wait(3000)) { throw 'TCP connection timed out.' }
        $stream = $client.GetStream()
        $stream.ReadTimeout = 3000
        # Read just the first protocol line, with a size limit. Do not download calibration or images.
        $line = New-Object System.Text.StringBuilder
        while ($line.Length -lt 1024) {
            $value = $stream.ReadByte()
            if ($value -lt 0 -or $value -eq 10) { break }
            [void]$line.Append([char]$value)
        }
        $hello = $line.ToString().Trim()
        if ($hello -notmatch '^H QuestLHSync 1 .*model=Steam_Frame(?: |$)') {
            throw 'The endpoint did not identify itself as a Steam Frame QuestLHSync daemon.'
        }
        Write-Host "OK: $Address`:47280 - $hello"
        Write-Host 'This checks the connection only. Verify camera frames and alignment in the VR dashboard.'
    } finally { $client.Dispose() }
}

try {
    if ($DriverPath -eq '') {
        # Source checkout: pc/setup.ps1; release: setup.ps1 next to questlhsync/.
        $releaseDriver = Join-Path $PSScriptRoot 'questlhsync'
        if (Test-Path -LiteralPath $releaseDriver) { $DriverPath = $releaseDriver }
        else { $DriverPath = Join-Path (Split-Path $PSScriptRoot) 'driver/questlhsync' }
    }
    $vr = Get-SteamVR
    if ($Action -eq 'Status') {
        Write-Host "SteamVR: $($vr.Exe)"
        & $vr.Exe show
        if ($LASTEXITCODE -ne 0) { throw 'vrpathreg show failed.' }
        if ($FrameHost -eq '' -and (Test-Path -LiteralPath $vr.Settings)) {
            $settings = Get-Content -LiteralPath $vr.Settings -Raw | ConvertFrom-Json
            $FrameHost = [string]$settings.driver_questlhsync.host
        }
        if ($FrameHost -eq '') {
            Write-Host 'Automatic discovery is configured. For a TCP check: .\status-pc.cmd <Frame-IP>'
        } else {
            foreach ($address in $FrameHost.Split(',')) { Test-FrameLink $address.Trim() }
        }
    } else {
        if (Get-Process -Name vrserver -ErrorAction SilentlyContinue) { throw 'Close SteamVR before installing or removing the PC driver.' }
        if ($Action -eq 'Remove') {
            $DriverPath = [System.IO.Path]::GetFullPath($DriverPath)
            & $vr.Exe removedriver $DriverPath
            if ($LASTEXITCODE -ne 0) { throw 'Driver unregistration failed.' }
            Write-Host 'PC driver unregistered. Saved alignment and settings are kept.'
        } else {
            $DriverPath = (Resolve-Path -LiteralPath $DriverPath).Path
            foreach ($file in @('bin/win64/driver_questlhsync.dll', 'bin/win64/QuestLHSync.exe', 'bin/win64/openvr_api.dll', 'driver.vrdrivermanifest')) {
                if (!(Test-Path -LiteralPath (Join-Path $DriverPath $file))) { throw "Missing build file: $file" }
            }
            # Read and validate settings before registering anything.
            if (Test-Path -LiteralPath $vr.Settings) {
                $settings = Get-Content -LiteralPath $vr.Settings -Raw | ConvertFrom-Json
            } else { $settings = New-Object PSObject }
            if (!$settings.driver_questlhsync) {
                $settings | Add-Member -NotePropertyName driver_questlhsync -NotePropertyValue (New-Object PSObject) -Force
            }
            $section = $settings.driver_questlhsync
            $section | Add-Member -NotePropertyName enable -NotePropertyValue $true -Force
            if ($PSBoundParameters.ContainsKey('FrameHost')) {
                $section | Add-Member -NotePropertyName host -NotePropertyValue $FrameHost -Force
            }
            if ($PSBoundParameters.ContainsKey('HeadsetSerial')) {
                $section | Add-Member -NotePropertyName headset -NotePropertyValue $HeadsetSerial -Force
            }
            $json = $settings | ConvertTo-Json -Depth 100
            if (Test-Path -LiteralPath $vr.Settings) {
                $backup = "$($vr.Settings).questlhsync-$(Get-Date -Format 'yyyyMMdd-HHmmss-fffffff').bak"
                Copy-Item -LiteralPath $vr.Settings -Destination $backup
                Write-Host "Settings backup: $backup"
            }
            & $vr.Exe adddriver $DriverPath
            if ($LASTEXITCODE -ne 0) { throw 'Driver registration failed.' }
            $settingsDir = Split-Path $vr.Settings
            [void][System.IO.Directory]::CreateDirectory($settingsDir)
            $tempFile = "$($vr.Settings).questlhsync.tmp"
            [System.IO.File]::WriteAllText($tempFile, $json, (New-Object System.Text.UTF8Encoding($false)))
            Move-Item -LiteralPath $tempFile -Destination $vr.Settings -Force
            Write-Host "Installed: $DriverPath"
            Write-Host 'Keep this folder in place. Install the headset package, then start SteamVR on your PC.'
        }
    }
} catch {
    Write-Error -ErrorAction Continue $_
    exit 1
}
