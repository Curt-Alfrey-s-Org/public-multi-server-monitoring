#Requires -Version 5.1
<#
.SYNOPSIS
  Install Dozzle agent inside WSL Ubuntu for central UI on 192.0.2.10:8888.

.DESCRIPTION
  Petals / llama RPC Docker runs in WSL on Windows workers. The agent mounts
  the WSL docker.sock and publishes :7007 for the central Dozzle UI.

.PARAMETER AgentHostname
  Sidebar label in Dozzle (e.g. operator-93).

.PARAMETER WslDistro
  WSL distribution name (default Ubuntu).

.PARAMETER MonitoringHost
  Central monitoring host IP (default 192.0.2.10).

.PARAMETER PublishPort
  Host port published from WSL (default 7007).

.EXAMPLE
  cd C:\path\to\monitoring\hosts\192.0.2.10
  .\install-dozzle-agent.ps1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $AgentHostname,
    [string] $WslDistro = 'Ubuntu',
    [string] $MonitoringHost = '192.0.2.10',
    [int] $PublishPort = 7007
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\setup-lib.ps1"
Start-AlfaMonitoringLog "dozzle-agent-$AgentHostname"

try {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    if ($repoRoot -match '^([A-Za-z]):\\(.*)$') {
        $wslRepo = '/mnt/' + $Matches[1].ToLower() + '/' + ($Matches[2] -replace '\\', '/')
    } else {
        throw "unsupported repo path for WSL: $repoRoot"
    }

    Write-AlfaMonitoringLog "WSL repo path: $wslRepo"
    Write-AlfaMonitoringLog "Agent hostname: $AgentHostname"

    $bashScript = @"
set -euo pipefail
export DOZZLE_AGENT_HOSTNAME='$AgentHostname'
export DOZZLE_AGENT_PUBLISH='${PublishPort}:7007'
cd '$wslRepo/hosts/_common'
chmod +x setup-dozzle-agent.sh
./setup-dozzle-agent.sh
"@

    Write-AlfaMonitoringLog "Running Dozzle agent setup inside WSL ($WslDistro)"
    $bashScript | wsl -d $WslDistro bash -lc "cat > /tmp/alfa-dozzle-agent-setup.sh; bash /tmp/alfa-dozzle-agent-setup.sh"

    Write-AlfaMonitoringLog "Checking WSL port ${PublishPort} is listening"
    $portCheck = wsl -d $WslDistro bash -lc "ss -ltn 2>/dev/null | grep -q ':${PublishPort} ' && echo OK || echo FAIL"
    if ($portCheck -notmatch 'OK') {
        throw "dozzle-agent port ${PublishPort} not listening in WSL"
    }

    Write-AlfaMonitoringLog "Windows firewall: allow TCP ${PublishPort} from ${MonitoringHost} (manual if needed)"
    Write-AlfaMonitoringLog "Done. Central UI: http://${MonitoringHost}:8888"
    Complete-AlfaMonitoringLog 0
}
catch {
    Write-AlfaMonitoringLog "FATAL: $($_.Exception.Message)"
    Complete-AlfaMonitoringLog 1
    throw
}
