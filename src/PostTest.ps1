##-----------------------------------------------------------------------
## <copyright file="PostTest.ps1">(c) Codeblack. All rights reserved.</copyright>
##-----------------------------------------------------------------------
<#
.SYNOPSIS
    Script for post-test stage in TFS build.
.DESCRIPTION
    Script for post-test stage in TFS build; handles packaging & publishing of nuget-packages.

    Author: Jeroen Swart
    Versions:
    - 1.0.0  07-12-2014  Initial version
    - 1.1.0  25-01-2015  Add parameter to explicitly enable packaging
    - 1.2.0  25-01-2015  Add Invoke-Release

.PARAMETER  NuspecFilePath
    Specifies the file-path for one or more nuspec-files, relative to the sources-directory.
    If not provided, all nuspec-files in the sources-directory will be processed.
.PARAMETER  BasePath
    Specifies the path to use as the base-path for the files in the nuspec-file(s), relative to the drop- or binaries-directory.
    If the drop-directory is present and populated, the base-path is relative to the drop-directory; otherwise it is relative to the binaries-directory.
    If not provided, or empty, the base-path is the drop- or binaries-directory itself.
.PARAMETER  OutputPath
    Specifies the path to use as the output-path for the package(s), relative to the drop-directory.
    Default is 'Package'.
.PARAMETER  AdditionalPackOptions
    Specifies additional command-line options for the pack-command.
.PARAMETER	Source
    Specifies the package-source to push the package(s) to.
.PARAMETER	ApiKey
    Specifies the API-key to use when pushing the package(s).
.PARAMETER	Push
    Specifies whether the package(s) should be pushed.
.PARAMETER  Disabled
    Convenience option so you can debug this script or disable it in your build definition
    without having to remove it from the 'Post-build script path' build process parameter.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string[]]$NuspecFilePath,
    [string]$BasePath,
    [Parameter(Mandatory = $false)]
    [string]$OutputPath,
    [Parameter(Mandatory = $false)]
    [string]$AdditionalPackOptions,
    [Parameter(Mandatory = $false)]
    [string]$Source,
    [Parameter(Mandatory = $false)]
    [string]$ApiKey,
    [Parameter(Mandatory = $false)]
    [switch]$Package = $false,
    [Parameter(Mandatory = $false)]
    [switch]$Push = $false,

    [Parameter(Mandatory = $false)]
    [switch]$Release = $false,
    [Parameter(Mandatory = $false)]
    [string]$TargetStageName,
    [Parameter(Mandatory = $false)]
    [string]$RMServer,
    [Parameter(Mandatory = $false)]
    [string]$RMPort = 1000,  
    [Parameter(Mandatory = $false)]
    [string]$TeamFoundationServerUrl,

    [Parameter(Mandatory = $false)]
    [switch]$Disabled = $false
)

# include the module containing common build-script functions.
Import-Module (Join-Path $PSScriptRoot Build.psm1)

# retrieve the necessary environment-variables, provided by the build-service (http://msdn.microsoft.com/en-us/library/hh850448.aspx)
$sourcesDirectory = Get-EnvironmentVariable "TF_BUILD_SOURCESDIRECTORY" -Verbose:$VerbosePreference
$binariesDirectory = Get-EnvironmentVariable "TF_BUILD_BINARIESDIRECTORY" -Verbose:$VerbosePreference
$dropDirectory = Get-EnvironmentVariable "TF_BUILD_DROPLOCATION" -Verbose:$VerbosePreference
$collectionUri = Get-EnvironmentVariable "TF_BUILD_COLLECTIONURI" -Verbose:$VerbosePreference
$buildUri = Get-EnvironmentVariable "TF_BUILD_BUILDURI" -Verbose:$VerbosePreference
$buildDefinitionName = Get-EnvironmentVariable "TF_BUILD_BUILDDEFINITIONNAME" -Verbose:$VerbosePreference
$buildNumber = Get-EnvironmentVariable "TF_BUILD_BUILDNUMBER" -Verbose:$VerbosePreference

if (-not $Disabled) {
    $build = Get-Build -CollectionUri $collectionUri -BuildUri $buildUri
    if ($build -and $build.CompilationStatus -eq "Succeeded" -and $build.TestStatus -eq "Succeeded") {

        if ($Release) {
            if (-not $TeamFoundationServerUrl) {
                $TeamFoundationServerUrl = $collectionUri
            }

            Invoke-Release -RMServer $RMServer -RMPort $RMPort `
                           -TeamFoundationServerUrl $TeamFoundationServerUrl `
                           -TeamProjectName $build.TeamProject `
                           -BuildDefinitionName $buildDefinitionName `
                           -BuildNumber $buildNumber `
                           -TargetStageName $TargetStageName
        }

        if ($Package) {
            New-NuGetPackage -SourcesDirectory $sourcesDirectory `
                             -BinariesDirectory $binariesDirectory `
                             -DropDirectory $dropDirectory `
                             -NuspecFilePath $NuspecFilePath `
                             -BasePath $BasePath `
                             -OutputPath $OutputPath `
                             -AdditionalPackOptions $AdditionalPackOptions

            if ($Push) {
                Push-NuGetPackage -DropDirectory $dropDirectory `
                                  -OutputPath $OutputPath `
                                  -Source $Source `
                                  -ApiKey $ApiKey
            }
            else {
                Write-Verbose "Push not enabled; pushing of NuGet-package(s) skipped"
            }
        }
        else {
            Write-Verbose "Package not enabled; packaging and pushing of NuGet-package(s) skipped"
        }
    }
}
else {
    Write-Verbose "Script disabled; processing of NuGet-packages skipped"
}
