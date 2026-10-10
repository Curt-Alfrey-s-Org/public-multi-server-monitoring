# Shared logging + verification for Windows setup scripts.
# Dot-source: . "$PSScriptRoot\setup-lib.ps1"

function Get-AlfaMonitoringLogDir {
    if ($env:ProgramData) {
        Join-Path $env:ProgramData 'AlfaMonitoring\setup-logs'
    } else {
        Join-Path $env:TEMP 'AlfaMonitoring-setup-logs'
    }
}

function Start-AlfaMonitoringLog {
    param([string]$Label = 'setup')
    $dir = Get-AlfaMonitoringLogDir
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    $script:AlfaSetupLog = Join-Path $dir "${Label}-${ts}.log"
    Write-AlfaMonitoringLog "=== begin $Label host=$env:COMPUTERNAME user=$env:USERNAME ==="
}

function Write-AlfaMonitoringLog {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format 'o'), $Message
    Write-Host $line
    if ($script:AlfaSetupLog) {
        Add-Content -Path $script:AlfaSetupLog -Value $line -Encoding UTF8
    }
}

function Complete-AlfaMonitoringLog {
    $dir = Get-AlfaMonitoringLogDir
    if ($script:AlfaSetupLog -and (Test-Path -LiteralPath $script:AlfaSetupLog)) {
        $latest = Join-Path $dir 'latest-run.log'
        Copy-Item -Force -LiteralPath $script:AlfaSetupLog -Destination $latest
        Write-AlfaMonitoringLog "wrote $latest (copy for scp pull from monitoring host)"
    }
}

function Test-AlfaMonitoringCommand {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "required command not found: $Name"
    }
}

function Test-AlfaMonitoringWindowsExporter {
    param(
        [int]$Port = 9182,
        [int]$TimeoutSec = 20
    )
    Write-AlfaMonitoringLog "checking: service windows_exporter"
    $svc = Get-Service -Name 'windows_exporter' -ErrorAction SilentlyContinue
    if (-not $svc) {
        throw 'service windows_exporter not found after install'
    }
    if ($svc.Status -ne 'Running') {
        throw "windows_exporter status is $($svc.Status), expected Running"
    }
    Write-AlfaMonitoringLog "checking: GET http://127.0.0.1:${Port}/metrics"
    $r = Invoke-WebRequest -Uri "http://127.0.0.1:${Port}/metrics" -UseBasicParsing -TimeoutSec $TimeoutSec
    if ($r.Content -notmatch '(?m)^# HELP ') {
        throw 'metrics endpoint did not return Prometheus exposition'
    }
    Write-AlfaMonitoringLog 'ok: windows_exporter running and /metrics looks valid'
}

function Push-AlfaMonitoringLog {
    param([string]$Dest = $env:ALFA_MONITORING_LOG_PUSH_DEST)
    if (-not $Dest -or -not $script:AlfaSetupLog) { return }
    if ($Dest -notmatch '^[^@]+@[^:]+:.+') {
        Write-AlfaMonitoringLog "WARN: ALFA_MONITORING_LOG_PUSH_DEST must be user@host:/path/ (got: $Dest)"
        return
    }
    Test-AlfaMonitoringCommand scp
    $colon = $Dest.IndexOf(':')
    $hostPart = $Dest.Substring(0, $colon)
    $pathPart = $Dest.Substring($colon + 1).TrimEnd('/', '\')
    $remoteFile = '{0}/{1}-setup-{2}.log' -f $pathPart, $env:COMPUTERNAME, (Get-Date -Format 'yyyyMMdd-HHmmss')
    Write-AlfaMonitoringLog "pushing log via scp to ${hostPart}:${remoteFile}"
    try {
        $scpArgs = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=10', '-p', $script:AlfaSetupLog, "${hostPart}:${remoteFile}")
        & scp @scpArgs
        if ($LASTEXITCODE -ne 0) { throw "scp exit $LASTEXITCODE" }
        Write-AlfaMonitoringLog 'ok: log pushed'
    } catch {
        Write-AlfaMonitoringLog "WARN: scp failed: $_"
    }
}
