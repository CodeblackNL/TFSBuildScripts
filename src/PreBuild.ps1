##-----------------------------------------------------------------------
## <copyright file="PreBuild.ps1">(c) https://github.com/CodeblackNL/TFSBuildScripts. See https://github.com/CodeblackNL/TFSBuildScripts/blob/master/LICENSE. </copyright>
##-----------------------------------------------------------------------
<#
.SYNOPSIS
    Script for pre-build stage in TFS build.
.DESCRIPTION
    Script for pre-build stage in TFS build; updates version attributes before building.

    Author: Jeroen Swart
    Versions:
    - 1.0.0  11-11-2014  Initial version
    - 1.1.0  07-12-2014  Added package versioning to Update-Version

.PARAMETER  $AssemblyVersionFilePattern
    Specifies the pattern to use for finding source-files containing the version-attributes. Default is 'AssemblyInfo.*'.
.PARAMETER  Version
    Specifies the version to use. May contain the following tokens :'YYYY', 'YY', 'M', 'D', 'J' and 'B'.
.PARAMETER  AssemblyVersionPattern
    Specifies the version, or pattern, for the assembly-version.
    Depending on the provided version (either through the Version or BuildNumber parameters)
    the default is '#.#.#.#' (.NET) or '#.#.#.0' (SemVer).
.PARAMETER  FileVersionPattern
    Specifies the version, or pattern, for the assembly-file-version.
    Depending on the provided version (either through the Version or BuildNumber parameters)
    the default is '#.#.#.#' (.NET) or '#.#.#.0' (SemVer).
.PARAMETER  $ProductVersionPattern
    Specifies the version, or pattern, for the assembly-informational-version.
    Depending on the provided version (either through the Version or BuildNumber parameters)
    the default is '#.#.#.#' (.NET) or '#.#.#.0' (SemVer).
.PARAMETER  PackageVersionPattern
    Specifies the version, or pattern, for the nuget-packages.
    Depending on the provided version (either through the Version or BuildNumber parameters)
    the default is '#.#.#.#' (.NET) or '#.#.###' (SemVer).
.PARAMETER  Disabled
    Convenience option so you can debug this script or disable it in your build definition
    without having to remove it from the 'Pre-build script path' build process parameter.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$AssemblyVersionFilePattern,
    [Parameter(Mandatory = $false)]
    [string]$Version,
    [Parameter(Mandatory = $false)]
    [string]$AssemblyVersionPattern,
    [Parameter(Mandatory = $false)]
    [string]$FileVersionPattern,
    [Parameter(Mandatory = $false)]
    [string]$ProductVersionPattern,
    [Parameter(Mandatory = $false)]
    [string]$PackageVersionPattern,
    [Parameter(Mandatory = $false)]
    [switch]$Disabled = $false
)

# include the module containing common build-script functions.
Import-Module (Join-Path $PSScriptRoot Build.psm1)

# retrieve the necessary environment-variables, provided by the build-service (http://msdn.microsoft.com/en-us/library/hh850448.aspx)
$buildNumber = Get-EnvironmentVariable -Name "TF_BUILD_BUILDNUMBER" -Verbose:$VerbosePreference
$sourcesDirectory = Get-EnvironmentVariable -Name "TF_BUILD_SOURCESDIRECTORY" -Verbose:$VerbosePreference

if (-not $Disabled) {
    Update-Version -SourcesDirectory $sourcesDirectory -AssemblyVersionFilePattern $AssemblyVersionFilePattern `
                   -BuildNumber $buildNumber -Version $Version `
                   -AssemblyVersionPattern $AssemblyVersionPattern `
                   -FileVersionPattern $FileVersionPattern `
                   -ProductVersionPattern $ProductVersionPattern `
				   -PackageVersionPattern $PackageVersionPattern `
                   -Verbose:$VerbosePreference
}
else {
    Write-Verbose "Script disabled; update of source-version skipped"
}
