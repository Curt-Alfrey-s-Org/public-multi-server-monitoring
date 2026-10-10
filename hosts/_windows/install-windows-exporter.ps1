#Requires -Version 5.1
<#
.SYNOPSIS
  Install prometheus-community windows_exporter for homelab Prometheus.

.DESCRIPTION
  Verifies admin, downloads MSI, installs, then verifies service + /metrics.
  Logs to ProgramData\AlfaMonitoring\setup-logs\ (latest-run.log for pull from ).

  Optional push: set env ALFA_MONITORING_LOG_PUSH_DEST=user@192.0.2.10:/path/incoming/

.PARAMETER PrometheusHost
  LAN IP allowed in the exporter firewall rule (default 192.0.2.10).

.PARAMETER Version
  Release tag without v (e.g. 0.29.1).

.PARAMETER EnabledCollectors
  MSI ENABLED_COLLECTORS value; default [defaults] plus container.

.EXAMPLE
  cd C:\path\to\monitoring\hosts\192.0.2.10
  .\install-metrics.ps1
#>
[CmdletBinding()]
param(
    [string] $PrometheusHost = '192.0.2.10',
    [string] $Version = '0.29.1',
    [string] $EnabledCollectors = '[defaults],container'
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\setup-lib.ps1"
Start-AlfaMonitoringLog 'windows-exporter'

try {
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Run in an elevated PowerShell (Run as administrator).'
    }

    Test-AlfaMonitoringCommand msiexec
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $verTag = "v$Version"
    $msiName = "windows_exporter-$Version-amd64.msi"
    $url = "https://github.com/"
    $msi = Join-Path $env:TEMP $msiName

    Write-AlfaMonitoringLog "Downloading $url"
    Invoke-WebRequest -Uri $url -OutFile $msi -UseBasicParsing
    if (-not (Test-Path -LiteralPath $msi)) { throw "download missing: $msi" }
    if ((Get-Item $msi).Length -lt 100000) { throw "download too small (corrupt?): $msi" }

    $msiArgs = @(
        '/i', $msi,
        '/qn', '/norestart',
        "REMOTE_ADDR=$PrometheusHost",
        "ENABLED_COLLECTORS=$EnabledCollectors"
    )

    Write-AlfaMonitoringLog "Installing: msiexec $($msiArgs -join ' ')"
    $p = Start-Process -FilePath msiexec.exe -ArgumentList $msiArgs -Wait -PassThru
    # 0 = success; 3010 = success, reboot pending (still OK for service)
    if ($p.ExitCode -notin 0, 3010) {
        throw "msiexec failed with exit code $($p.ExitCode). Retry with -EnabledCollectors '[defaults]' if collectors failed."
    }

    Start-Sleep -Seconds 3
    Test-AlfaMonitoringWindowsExporter -Port 9182

    Write-AlfaMonitoringLog "Done. Prometheus scrapes: http://<this-pc-lan-ip>:9182/metrics"
}
catch {
    Write-AlfaMonitoringLog "FATAL: $_"
    Complete-AlfaMonitoringLog
    Push-AlfaMonitoringLog
    throw
}

Complete-AlfaMonitoringLog
Push-AlfaMonitoringLog
