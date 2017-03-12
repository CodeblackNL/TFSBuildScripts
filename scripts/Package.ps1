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
    - 1.0.0  12-03-2017  Initial version
#>

$nugetFilePath = Join-Path -Path $PSScriptRoot -ChildPath 'nuget.exe'
$nugetFolderPath = Join-Path -Path $PSScriptRoot -ChildPath '..\nuget'
$nuspecFilePath = Join-Path -Path $nugetFolderPath -ChildPath 'TFSBuildScripts.nuspec'
$packagesFolderPath = Join-Path -Path $nugetFolderPath -ChildPath 'packages'

Push-Location $nugetFolderPath

New-Item -Path $packagesFolderPath -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

Invoke-Expression "$nugetFilePath pack '$nuspecFilePath' -OutputDirectory '$packagesFolderPath'"

Pop-Location