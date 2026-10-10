#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Install nvidia_gpu_exporter for GPU temps/metrics on Windows (Prometheus scrape :9835).

.DESCRIPTION
  Uses nvidia-smi via https://github.com/utkuozdemir/nvidia_gpu_exporter (Windows binary).
  Metric: nvidia_smi_temperature_gpu (Celsius).

  DCGM exporter is Linux-only per NVIDIA docs; this is the homelab Windows path.

.PARAMETER PrometheusHost
  LAN IP allowed in firewall (default 192.0.2.10, Grafana/Prometheus VM).

.PARAMETER Version
  Release tag without v (e.g. 1.3.2).

.PARAMETER ListenPort
  HTTP /metrics port (default 9835).

.EXAMPLE
  cd C:\path\to\monitoring\hosts\192.0.2.10
  .\install-gpu-metrics.ps1
#>
[CmdletBinding()]
param(
    [string] $PrometheusHost = '192.0.2.10',
    [string] $Version = '1.6.0',
    [int] $ListenPort = 9835
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\setup-lib.ps1"

function Test-AlfaMonitoringNvidiaGpuExporter {
    param(
        [int]$Port = 9835,
        [int]$TimeoutSec = 25
    )
    Write-AlfaMonitoringLog "checking: GET http://127.0.0.1:${Port}/metrics"
    $r = Invoke-WebRequest -Uri "http://127.0.0.1:${Port}/metrics" -UseBasicParsing -TimeoutSec $TimeoutSec
    if ($r.Content -notmatch '(?m)^# HELP ') {
        throw 'metrics endpoint did not return Prometheus exposition'
    }
    if ($r.Content -notmatch 'nvidia_smi_temperature_gpu') {
        throw 'nvidia_smi_temperature_gpu metric not found in /metrics'
    }
    Write-AlfaMonitoringLog 'ok: nvidia_gpu_exporter /metrics includes GPU temperature'
}

Start-AlfaMonitoringLog 'nvidia-gpu-exporter'

$InstallRoot = Join-Path ${env:ProgramFiles} 'AlfaMonitoring\nvidia_gpu_exporter'
$TaskName = 'AlfaNvidiaGpuExporter'

try {
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Run in an elevated PowerShell (Run as administrator).'
    }

    Test-AlfaMonitoringCommand nvidia-smi
    nvidia-smi -L | ForEach-Object { Write-AlfaMonitoringLog $_ }

    New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
    $exe = Get-ChildItem -Path $InstallRoot -Filter 'nvidia_gpu_exporter*.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($exe) {
        Write-AlfaMonitoringLog ("using existing binary: {0}" -f $exe.FullName)
    } else {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $verTag = "v$Version"
        $zipName = "nvidia_gpu_exporter_${Version}_windows_x86_64.zip"
        $url = "https://github.com/utkuozdemir/nvidia_gpu_exporter/releases/download/$verTag/$zipName"
        $zip = Join-Path $env:TEMP $zipName
        Write-AlfaMonitoringLog "Downloading $url"
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
        if (-not (Test-Path -LiteralPath $zip)) { throw "download missing: $zip" }
        if ((Get-Item $zip).Length -lt 500000) { throw "download too small (corrupt?): $zip" }
        Expand-Archive -LiteralPath $zip -DestinationPath $InstallRoot -Force
        $exe = Get-ChildItem -Path $InstallRoot -Filter 'nvidia_gpu_exporter*.exe' -Recurse | Select-Object -First 1
    }
    if (-not $exe) { throw "nvidia_gpu_exporter.exe not found under $InstallRoot" }
    $exePath = $exe.FullName
    Write-AlfaMonitoringLog "binary: $exePath"

    $listenArg = ":{0}" -f $ListenPort
    $taskArgs = "--web.listen-address=$listenArg"

    Get-Process -Name 'nvidia_gpu_exporter' -ErrorAction SilentlyContinue | ForEach-Object {
        Write-AlfaMonitoringLog ("stopping existing nvidia_gpu_exporter id={0}" -f $_.Id)
        Stop-Process -Id $_.Id -Force
    }
    Start-Sleep -Seconds 2

    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existing) {
        Write-AlfaMonitoringLog "removing existing scheduled task: $TaskName"
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }

    $action = New-ScheduledTaskAction -Execute $exePath -Argument $taskArgs
    $trigger = New-ScheduledTaskTrigger -AtStartup
    # Default ExecutionTimeLimit is 72 hours and would kill a long-running exporter.
    # PT0S / TimeSpan.Zero = run indefinitely:
    # https://learn.microsoft.com/
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -RunLevel Highest -User 'SYSTEM' | Out-Null
    Write-AlfaMonitoringLog "registered scheduled task: $TaskName (SYSTEM, AtStartup, no execution time limit)"

    Start-ScheduledTask -TaskName $TaskName
    Start-Sleep -Seconds 4

    $ruleName = 'Alfa Nvidia GPU Exporter Prometheus'
    $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    if ($existingRule) {
        Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    }
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort $ListenPort -RemoteAddress $PrometheusHost | Out-Null
    Write-AlfaMonitoringLog "firewall: allow TCP $ListenPort from $PrometheusHost"

    Test-AlfaMonitoringNvidiaGpuExporter -Port $ListenPort

    Write-AlfaMonitoringLog "Done. Prometheus scrapes: http://<this-pc-lan-ip>:${ListenPort}/metrics"
    Write-AlfaMonitoringLog "GPU temp metric: nvidia_smi_temperature_gpu"
}
catch {
    Write-AlfaMonitoringLog "FATAL: $_"
    Complete-AlfaMonitoringLog
    Push-AlfaMonitoringLog
    throw
}

Complete-AlfaMonitoringLog
Push-AlfaMonitoringLog
