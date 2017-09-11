# Credits

Brandon Royal, Michael Friis

# Instructions

## Installation with PowerShell

```
Login-AzureRmAccount

git clone https://github.com/uday-shetty/azurestack-test

cd azurestack-test

$resource_group_name="<some-resource-group-you-pre-created>"

$adminPassword="<some-pw-with-special-char-and-capital-letters>"
$sshPublicKey="<your-pup-key>"
$prefix="<some-prefix-less-than-7-chars>"
$ucpVersion="2.2.0"
$dtrVersion="2.3.0"
$dockerVersion="17.06"
$dockerEEurl="<URL to download to Docker EE -- get it from https://store.docker.com>"
$workerCount=1, 2 or 3

$parameters = @{'workerCount' = $workerCount; 'prefix' = $prefix; 'adminUsername' = "docker"; 'adminPassword' = $adminPassword; 'sshPublicKey' = $sshPublicKey; 'ucpVersion' = $ucpVersion; 'dtrVersion' = $dtrVersion; 'dockerVersion' = $dockerVersion; 'dockerEEurl' = $dockerEEurl}

New-AzureRmResourceGroupDeployment -ResourceGroupName $resource_group_name `
  -TemplateUri 'https://raw.githubusercontent.com/uday-shetty/azurestack-test/master/azuredeploy.json' `
  -TemplateParameterObject $parameters `
  -Verbose

```

## Setup

1. Find `MGR_UCP_HOSTNAME` in deployment output in Azure portal. Visit this in browser (using `https`) and log in with `admin` and the admin password
2. Visit `/manage/resources/nodes/create` to get the swarm join command
3. Remote-desktop into each worker (the above sample creates just one) and run the join command in PowerShell

Your swarm is now ready to use
