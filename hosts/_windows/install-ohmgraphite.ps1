#Requires -Version 5.1
<#
.SYNOPSIS
  Install OhmGraphite for Windows CPU/hardware temps (Prometheus scrape).

.DESCRIPTION
  Exposes ohm_cpu_celsius and related sensors on HTTP :4445 for Prometheus on .
  Requires PawnIO for CPU temperature (https://pawnio.eu/) per OhmGraphite docs.

.PARAMETER PrometheusHost
  LAN IP allowed in firewall (default 192.0.2.10).

.PARAMETER Version
  OhmGraphite release without v prefix (default 0.34.0).

.PARAMETER ListenPort
  Prometheus exporter port (default 4445).

.EXAMPLE
  cd C:\Users\operator\monitoring\hosts\192.0.2.10
  .\install-cpu-temps.ps1
#>
[CmdletBinding()]
param(
    [string] $PrometheusHost = '192.0.2.10',
    [string] $Version = '0.38.0',
    [int] $ListenPort = 4445
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\setup-lib.ps1"

function Test-AlfaMonitoringOhmGraphite {
    param(
        [int]$Port = 4445,
        [int]$TimeoutSec = 30
    )
    $url = "http://127.0.0.1:${Port}/metrics/"
    Write-AlfaMonitoringLog "checking: GET $url"
    $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec $TimeoutSec
    if ($r.Content -notmatch '(?m)^# HELP ') {
        throw 'metrics endpoint did not return Prometheus exposition'
    }
    Write-AlfaMonitoringLog 'ok: OhmGraphite /metrics/ responds'
    if ($r.Content -match 'ohm_cpu_celsius') {
        Write-AlfaMonitoringLog 'ok: ohm_cpu_celsius present'
    } else {
        Write-AlfaMonitoringLog 'WARN: ohm_cpu_celsius missing - install PawnIO from https://pawnio.eu/ and reboot if needed'
    }
}

Start-AlfaMonitoringLog 'ohmgraphite'

$InstallRoot = Join-Path ${env:ProgramFiles} 'AlfaMonitoring\OhmGraphite'
$ServiceExe = Join-Path $InstallRoot 'OhmGraphite.exe'

try {
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Run in an elevated PowerShell (Run as administrator).'
    }

    $pawnSvc = Get-Service -Name 'PawnIO' -ErrorAction SilentlyContinue
    if (-not $pawnSvc -or $pawnSvc.Status -ne 'Running') {
        throw 'PawnIO must be installed and Running before OhmGraphite (avoids WinRing0 / VulnerableDriver:WinNT/Winring0). Install Official edition from https://pawnio.eu/ then re-run. See docs/WINRING0_PAWNIO.md'
    }
    Write-AlfaMonitoringLog "PawnIO service status: $($pawnSvc.Status)"
    if ([version]$Version -lt [version]'0.36.0') {
        throw "OhmGraphite $Version ships WinRing0. Use -Version 0.38.0 or newer (docs/WINRING0_PAWNIO.md)."
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $zipName = "OhmGraphite-$Version.zip"
    $url = "https://github.com/nickbabcock/OhmGraphite/releases/download/v$Version/$zipName"
    $zip = Join-Path $env:TEMP $zipName

    Write-AlfaMonitoringLog "Downloading $url"
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    if (-not (Test-Path -LiteralPath $zip)) { throw "download missing: $zip" }
    if ((Get-Item $zip).Length -lt 500000) { throw "download too small (corrupt?): $zip" }

    if (Test-Path -LiteralPath $InstallRoot) {
        Write-AlfaMonitoringLog "stopping existing OhmGraphite service if present"
        if (Test-Path -LiteralPath $ServiceExe) {
            Push-Location $InstallRoot
            try {
                & $ServiceExe stop 2>$null
            } catch {
                Write-AlfaMonitoringLog "stop skipped: $_"
            }
            Pop-Location
        }
    }

    New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
    Expand-Archive -LiteralPath $zip -DestinationPath $InstallRoot -Force

    if (-not (Test-Path -LiteralPath $ServiceExe)) { throw "OhmGraphite.exe not found under $InstallRoot" }

    $configPath = Join-Path $InstallRoot 'OhmGraphite.exe.config'
    $examplePath = Join-Path $PSScriptRoot 'ohmgraphite.exe.config.example'
    if (Test-Path -LiteralPath $examplePath) {
        Copy-Item -LiteralPath $examplePath -Destination $configPath -Force
        Write-AlfaMonitoringLog "config copied from $examplePath"
    } else {
        $portLine = $ListenPort.ToString()
        @"
<?xml version="1.0" encoding="utf-8" ?>
<configuration>
  <appSettings>
    <add key="type" value="prometheus" />
    <add key="prometheus_port" value="$portLine" />
    <add key="prometheus_host" value="*" />
    <add key="prometheus_path" value="metrics/" />
  </appSettings>
</configuration>
"@ | Set-Content -LiteralPath $configPath -Encoding UTF8
        Write-AlfaMonitoringLog "config written: $configPath"
    }

    Push-Location $InstallRoot
    try {
        Write-AlfaMonitoringLog 'OhmGraphite.exe install'
        & $ServiceExe install
        Write-AlfaMonitoringLog 'OhmGraphite.exe start'
        & $ServiceExe start
    } finally {
        Pop-Location
    }

    Start-Sleep -Seconds 5

    $ruleName = 'Alfa OhmGraphite Prometheus'
    $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    if ($existingRule) {
        Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    }
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort $ListenPort -RemoteAddress $PrometheusHost | Out-Null
    Write-AlfaMonitoringLog "firewall: allow TCP $ListenPort from $PrometheusHost"

    Test-AlfaMonitoringOhmGraphite -Port $ListenPort

    Write-AlfaMonitoringLog "Done. Prometheus scrapes: http://<this-pc-lan-ip>:${ListenPort}/metrics/"
        $sysPath = Join-Path $InstallRoot 'OhmGraphite.sys'
    if (Test-Path -LiteralPath $sysPath) {
        throw "OhmGraphite.sys present (WinRing0). Stop service, remove .sys, ensure PawnIO + OhmGraphite >= 0.36. See docs/WINRING0_PAWNIO.md"
    }
    Write-AlfaMonitoringLog 'ok: no OhmGraphite.sys (WinRing0 absent)'
    Write-AlfaMonitoringLog 'CPU temp metric: ohm_cpu_celsius'
}
catch {
    Write-AlfaMonitoringLog "FATAL: $_"
    Complete-AlfaMonitoringLog
    Push-AlfaMonitoringLog
    throw
}

Complete-AlfaMonitoringLog
Push-AlfaMonitoringLog
