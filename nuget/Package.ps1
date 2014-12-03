##-----------------------------------------------------------------------
## <copyright file="Package.ps1">(c) https://github.com/CodeblackNL/TFSBuildScripts. See https://github.com/CodeblackNL/TFSBuildScripts/blob/master/LICENSE. </copyright>
##-----------------------------------------------------------------------
<#
.SYNOPSIS
    Creates a new TFSBuildScripts NuGet-package.
.DESCRIPTION
    Creates a new TFSBuildScripts NuGet-package, in a 'packages' sub-folder, using the TFSBuildScripts.nuspec file.

    Author: Jeroen Swart
    Versions:
    - 1.0.0  03-12-2014  Initial version
#>

$location = Get-Location
Set-Location $PSScriptRoot

mkdir "packages" -ErrorAction SilentlyContinue

Invoke-Expression "NuGet.exe pack .\TFSBuildScripts.nuspec -OutputDirectory packages"

Set-Location $location
