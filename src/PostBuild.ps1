##-----------------------------------------------------------------------
## <copyright file="PostBuild.ps1">(c) Codeblack. All rights reserved.</copyright>
##-----------------------------------------------------------------------
<#
.SYNOPSIS
    Script for post-build stage in TFS build.
.DESCRIPTION
    Script for post-build stage in TFS build; runs sonar analysis after building.

    Author: Jeroen Swart
    Versions:
    - 1.0.0  05-12-2014  Initial version

.PARAMETER  SonarRunnerBinFolder
    Specifies the folder containing the SonarRunner binaries. Default is 'C:\sonar\bin'.
.PARAMETER  SonarPropertiesFileName
    Specifies the name of the sonar-properties file. Default is 'sonar-project.properties'.
.PARAMETER  Disable
    Convenience option so you can debug this script or disable it in your build definition
    without having to remove it from the 'Post-build script path' build process parameter.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$SonarRunnerBinFolder,
    [Parameter(Mandatory = $false)]
    [string]$SonarPropertiesFileName,
    [Parameter(Mandatory = $false)]
    [switch]$Disable = $false
)

# include the module containing common build-script functions.
Import-Module (Join-Path $PSScriptRoot Build.psm1)

# retrieve the necessary environment-variables, provided by the build-service (http://msdn.microsoft.com/en-us/library/hh850448.aspx)
$sourcesDirectory = Get-EnvironmentVariable "TF_BUILD_SOURCESDIRECTORY" -Verbose:$VerbosePreference

if (-not $Disabled) {
    try {
		Remove-BOM -Directory $sourcesDirectory

        Invoke-SonarRunner -SourcesDirectory $sourcesDirectory `
		                   -SonarRunnerBinFolder $SonarRunnerBinFolder `
	                       -SonarPropertiesFileName $SonarPropertiesFileName `
                           -Verbose:$VerbosePreference
    }
    catch { }
}
else {
    Write-Verbose "Script disabled; Sonar analysis skipped"
}
