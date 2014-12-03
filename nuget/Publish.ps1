##-----------------------------------------------------------------------
## <copyright file="Publish.ps1">(c) https://github.com/CodeblackNL/TFSBuildScripts. See https://github.com/CodeblackNL/TFSBuildScripts/blob/master/LICENSE. </copyright>
##-----------------------------------------------------------------------
<#
.SYNOPSIS
    Publishes a TFSBuildScripts NuGet-package to nuget.org.
.DESCRIPTION
    Publishes a specific version of the TFSBuildScripts NuGet-package to nuget.org, from the 'packages' sub-folder.

    Author: Jeroen Swart
    Versions:
    - 1.0.0  03-12-2014  Initial version

.PARAMETER  $Version
    Specifies the version of the package to publish.
.PARAMETER  $ApiKey
    Specifies the (optional) API-key to use.
#>

param (
	[Parameter(Mandatory = $true)]
	[string]$Version,
	[Parameter(Mandatory = $false)]
	[string]$ApiKey
)

$location = Get-Location
Set-Location $PSScriptRoot

$packagePath = ".\packages\TFSBuildScripts.$Version.nupkg"
if (-not (Test-Path $packagePath)) {
	Write-Host "Package not found at '$packagePath'." -ForegroundColor Red -BackgroundColor Black
	return
}

Invoke-Expression "NuGet.exe push $packagePath $ApiKey"

Set-Location $location
