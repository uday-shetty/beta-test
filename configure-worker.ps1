[CmdletBinding()]
Param(
  [switch] $SkipEngineUpgrade,
  [string] $DockerVersion,
  [string] $UCPFQDN,
  [string] $UcpVersion,
  [string] $LeaderIP
)

#Variables
$Date = Get-Date -Format "yyyy-MM-dd HHmmss"
$DockerDataPath = "C:\ProgramData\Docker"


function Join-Swarm() {
    try
    {
	Write-Host "Leader IP: $LeaderIP"

	$Url = -join("http://", $LeaderIP, ":9024/token/worker/")
	Write-Host "Using URL: $Url"
	$i = 1
	do {
		$i
		$i++

		# First we create the request.
		$HTTP_Request = [System.Net.WebRequest]::Create($Url)

		# We then get a response from the site.
		$HTTP_Response = $HTTP_Request.GetResponse()

		# We then get the HTTP code as an integer.
		$HTTP_Status = [int]$HTTP_Response.StatusCode
		Write-Host "HTTP Code inside loop: $HTTP_Status"

		if ($HTTP_Status -eq 200) {
			break
		}
		Start-Sleep -Seconds 20
	
	} while (i -le 10)
	$Stream = ([System.Net.WebRequest]::Create($Url)).GetResponse().GetResponseStream()
	$StreamReader = new-object System.IO.StreamReader $Stream
	$Token = $StreamReader.ReadToEnd()
	Write-Host "Obtained token and Joining swarm"
	$JoinTarget = -join($LeaderIP, ":2377")
	docker.exe swarm join --token $Token $JoinTarget
	return 0
    }
    catch
    {
	Write-Host "Exception encountered: "
	Write-Host $_.Exception|format-list -force
    }
}

function Disable-RealTimeMonitoring () {
    Set-MpPreference -DisableRealtimeMonitoring $true
}

function Install-LatestDockerEngine () {
    #Get Docker Engine from Master Builds
    Invoke-WebRequest -Uri "https://download.docker.com/components/engine/windows-server/17.06/docker-17.06.1-ee-2.zip" -OutFile "docker.zip"

    Stop-Service docker
    Remove-Item -Force -Recurse $env:ProgramFiles\docker
    Expand-Archive -Path "docker.zip" -DestinationPath $env:ProgramFiles -Force
    Remove-Item docker.zip

    Start-Service docker
}

function Disable-Firewall () {
    #Disable firewall (temporary)
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

    #Ensure public profile is disabled (solves public profile not persisting issue)
    $data = netsh advfirewall show publicprofile
    $data = $data[3]
    if ($data -Match "ON"){
        Set-NetFirewallProfile -Profile Public -Enabled False
    }
}

function Set-UcpHostnameEnvironmentVariable() {
    $UCPFQDN | Out-File (Join-Path $DockerDataPath "ucp_fqdn")
}

function Get-UcpImages() {
    docker pull docker/ucp-dsinfo-win:$UcpVersion
    docker pull docker/ucp-agent-win:$UcpVersion

    Add-Content setup.ps1 $(docker run --rm docker/ucp-agent-win:$UcpVersion windows-script)
    & .\setup.ps1
    Remove-Item -Force setup.ps1
}

#Start Script
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

try
{
    Start-Transcript -path "C:\ProgramData\Docker\configure-worker $Date.log" -append

    Write-Host "Disabling Real Time Monitoring"
    Disable-RealTimeMonitoring
    
    if (-not ($SkipEngineUpgrade.IsPresent)) {
        Write-Host "Upgrading Docker Engine"
        Install-LatestDockerEngine
    }

    Write-Host "Getting UCP Images"
    Get-UcpImages

    Write-Host "Disabling Firewall"
    Disable-Firewall

    Write-Host "Set UCP FQDN Environment Variable"
    Set-UcpHostnameEnvironmentVariable

    Write-Host "Join Swarm Cluster"
    Join-Swarm

    Stop-Transcript
}
catch
{
    Write-Error $_
}
