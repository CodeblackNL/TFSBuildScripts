<#
.SYNOPSIS
    Script for updating the version as part of a TFS build.
.DESCRIPTION
    Script for updating the version as part of a TFS build; updates version attributes before building.

    Author: Jeroen Swart
    Versions:
    - 1.0.0  11-11-2014  Initial version
    - 1.1.0  07-12-2014  Added package versioning to Update-Version
    - 2.0.0  28-08-2016  Update for task-based builds
    - 2.1.0  25-05-2017  Change default format for .NET, when SemVer is provided, to '#.#.#.B'

.PARAMETER  $AssemblyVersionFilePattern
    Specifies the pattern to use for finding source-files containing the version-attributes. Default is 'AssemblyInfo.*'.
.PARAMETER  Version
    Specifies the version to use. May contain the following tokens :'YYYY', 'YY', 'M', 'D', 'J' and 'B'.
.PARAMETER  AssemblyVersionPattern
    Specifies the version, or pattern, for the assembly-version.
    Depending on the provided version (either through the Version or BuildNumber parameters)
    the default is '#.#.#.#' (.NET) or '#.#.#.B' (SemVer).
.PARAMETER  FileVersionPattern
    Specifies the version, or pattern, for the assembly-file-version.
    Depending on the provided version (either through the Version or BuildNumber parameters)
    the default is '#.#.#.#' (.NET) or '#.#.#.B' (SemVer).
.PARAMETER  $ProductVersionPattern
    Specifies the version, or pattern, for the assembly-informational-version.
    Depending on the provided version (either through the Version or BuildNumber parameters)
    the default is '#.#.#.#' (.NET) or '#.#.###' (SemVer).
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
    [string]$Version,
    [Parameter(Mandatory = $false)]
    [string]$AssemblyVersionFilePattern,
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

set-alias ?: Invoke-Ternary -Option AllScope -Description "PSCX filter alias"
filter Invoke-Ternary ([scriptblock]$decider, [scriptblock]$ifTrue, [scriptblock]$ifFalse) {
    if (& $decider) { 
        & $ifTrue
    } else { 
        & $ifFalse 
    }
}

function Update-Version {
<#
    .SYNOPSIS
        Updates the version-attributes in source-code.
    .DESCRIPTION
        Updates the version-attributes, using a base-version and patterns.
        The base-version can be provided, or is retrieved from the build-number.
        Versions may be specified in a .Net (0.0.0.0) or SemVer (semver.org) format.

        For example, if the 'Build number format' build process parameter is
        $(BuildDefinitionName)_$(Year:yyyy).$(Month).$(DayOfMonth)$(Rev:.r),
        then your build numbers come out like this: "HelloWorld_2014.11.08.2".
        This function would then apply version 2014.11.8.2.

    .PARAMETER  SourcesDirectory
        Specifies the root-directory containing the source-files.
    .PARAMETER  AssemblyVersionFilePattern
        Specifies the pattern to use for finding source-files containing the version-attributes. Default is 'AssemblyInfo.*'.
    .PARAMETER  BuildNumber
        Specifies the build-number from which to take the version-number, if available.
        This parameter is ignored if the Version parameter is provided.
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
    .PARAMETER  ProductVersionPattern
        Specifies the version, or pattern, for the assembly-informational-version.
        Depending on the provided version (either through the Version or BuildNumber parameters)
        the default is '#.#.#.#' (.NET) or '#.#.###' (SemVer).
    .PARAMETER  PackageVersionPattern
        Specifies the version, or pattern, for the nuget-packages.
        Depending on the provided version (either through the Version or BuildNumber parameters)
        the default is '#.#.#.#' (.NET) or '#.#.###' (SemVer).
    .PARAMETER  WhatIf
        Specifies that no changes should be made.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SourcesDirectory,
        [Parameter(Mandatory = $false)]
        [string]$AssemblyVersionFilePattern,
        [Parameter(Mandatory = $true)]
        [string]$BuildNumber,
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
        [switch]$WhatIf = $false
    )

    function Get-VersionData {
        param (
            [string]$VersionString
        )

        # check for .NET-format first
        $versionMatch = [regex]::match($VersionString, '(?<major>\d+)\.(?<minor>\d+)\.(?<build>\d+)\.(?<revision>\d+)')
        if ($versionMatch.Success -and $versionMatch.Count -ne 0) {
            $versionType = "dotNET"
        }

        if (-not $versionMatch.Success -or $versionMatch.Count -eq 0) {
            # check for SemVer-format next
            $versionMatch = [regex]::match($VersionString, '(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)(?<prerelease>-[0-9a-z][0-9a-z-.]*)?(?<buildmetadata>\+[0-9a-z][0-9a-z-.]*)?')
            if ($versionMatch.Success -and $versionMatch.Count -ne 0) {
                $versionType = "SemVer"
            }
        }

        switch ($versionMatch.Count) {
            0 {
                Write-Error "Could not find version number data."
                exit 1
            }
            1 { }
            default {
                Write-Warning "Found more than instance of version in the build-number; will assume last instance is version."
                $versionMatch = $versionMatch[$versionMatch.Count - 1]
            }
        }

        return @{
            Type = $versionType
            Major = $versionMatch.Groups['major'] | ?: { $_ } { [int]$_.Value } { 0 }
            Minor = $versionMatch.Groups['minor'] | ?: { $_ } { [int]$_.Value } { 0 }
            Build = $versionMatch.Groups['build'] | ?: { $_ } { [int]$_.Value } { 0 }
            Revision = $versionMatch.Groups['revision'] | ?: { $_ } { [int]$_.Value } { 0 }
            Patch = $versionMatch.Groups['patch'] | ?: { $_ } { [int]$_.Value } { 0 }
            PreRelease = $versionMatch.Groups['prerelease'] | ?: { $_ } { $_.Value } { "" }
            BuildMetadata = $versionMatch.Groups['buildmetadata'] | ?: { $_ } { $_.Value } { "" }
        }
    }

    function Format-Version {
        param (
        [Parameter(Mandatory = $true)]
            [string]$VersionFormat,
            [Parameter(Mandatory = $false)]
            [Hashtable]$VersionData,
            [Parameter(Mandatory = $false)]
            [int]$Rev,
            [Parameter(Mandatory = $false)]
            [switch]$NuGetPackageVersion
        )

        # normalize version format
        $normalizedVersionFormat = $VersionFormat -replace '\{(\d+)\}', '{{$1}}'

        # process replacement-tokens using base-version
        if ($VersionData) {
            # replace short notation
            $versionPosition = 0
            for ($index = 0; $index -lt $normalizedVersionFormat.Length; $index++) {
                $char = $normalizedVersionFormat[$index]
                if ($char -eq "#") {
                    $version += "{$versionPosition}"
                    $versionPosition++
                }
                else {
                    $version += $char
                }
            }

            ## replace full notation
            #$newVersionFormat = $newVersionFormat -replace "{major(:\d+)?}", '{0$1}'
            #$newVersionFormat = $newVersionFormat -replace "{minor(:\d+)?}", '{1$1}'
            #$newVersionFormat = $newVersionFormat -replace "{build(:\d+)?}", '{2$1}'
            #$newVersionFormat = $newVersionFormat -replace "{revision(:\d+)?}", '{3$1}'

            if ($VersionData.Type -eq "SemVer") {
                if ($NuGetPackageVersion) {
                    # NuGet doesn't fully support semver
                    # - dot separated identifiers
                    $VersionData.PreRelease = $VersionData.PreRelease.Replace(".", "-")
                    $VersionData.BuildMetadata = $VersionData.BuildMetadata.Replace(".", "-")

                    # build-metadata
                    if ($VersionData.PreRelease -and $VersionData.PreRelease.Length -gt 0 -and -not [char]::IsDigit($VersionData.PreRelease, $VersionData.PreRelease.Length - 1)) {
                        $VersionData.BuildMetadata = $VersionData.BuildMetadata.Replace("+", "")
                    }
                    else {
                        $VersionData.BuildMetadata = $VersionData.BuildMetadata.Replace("+", "-")
                    }
                }

                $version = $version -f $VersionData.Major, $VersionData.Minor, $VersionData.Patch, $VersionData.PreRelease, $VersionData.BuildMetadata
            }
            else {
                $version = $version -f $VersionData.Major, $VersionData.Minor, $VersionData.Build, $VersionData.Revision
            }
        }
        else {
            $version = $VersionFormat
        }

        # process replacement-tokens with datetime & build-number symbols
        $now = [DateTime]::Now
        if (-not $Rev -and $VersionData) {
            if ($VersionData.Type -eq "SemVer") {
                $revMatch = [regex]::match($VersionData.BuildMetadata, '\d+$')
                if ($revMatch.Success) {
                    $Rev = [int]$revMatch.Groups[0].Value
                }
            }
            else {
                $Rev = $VersionData.Revision
            }
        }
        if (-not $Rev) {
            $Rev = 0
        }

        $version = $version -creplace 'YYYY', $now.Year
        $version = $version -creplace 'YY', $now.ToString("yy")
        $version = $version -creplace '\.MM', ".$($now.Month)"
        $version = $version -creplace 'MM', ('{0:00}' -f $now.Month)
        $version = $version -creplace 'M', $now.Month
        $version = $version -creplace '\.DD', ".$($now.Day)"
        $version = $version -creplace 'DD', ('{0:00}' -f $now.Day)
        $version = $version -creplace 'D', $now.Day
        $version = $version -creplace 'J', "$($now.ToString("yy"))$('{0:000}' -f [int]$now.DayOfYear)"
        if (-not $version.Contains("+")) {
            $version = $version -creplace '\.BBB', ".$Rev"
            $version = $version -creplace '\.BB', ".$Rev"
        }
        $version = $version -creplace 'BBB', ('{0:000}' -f [int]$Rev)
        $version = $version -creplace 'BB', ('{0:00}' -f [int]$Rev)
        $version = $version -creplace 'B', $Rev

        return $version
    }
    
    # if a search-pattern for the files containing the version-attributes is not provided, use the default
    if(-not $AssemblyVersionFilePattern) {
        $AssemblyVersionFilePattern = "AssemblyInfo.*"
    }

    # if the version is not explicitly provided
    if (-not $Version) {
        # get version-data from the build-number
        $versionData = Get-VersionData -VersionString $BuildNumber
    }
    else {
        # get version-data from the build-number
        $versionData = Get-VersionData -VersionString $BuildNumber
        $Version = Format-Version -VersionData $versionData -VersionFormat $Version

        # get version-data from the provided version
        $versionData = Get-VersionData -VersionString $Version
    }

    # determine default version-patterns, based on the type of version used, for those that are not provided
    # assembly-version & file-version do not support SemVer, so use #.#.#.B pattern
    if(-not $AssemblyVersionPattern) {
        $AssemblyVersionPattern = $versionData.Type | ?: { $_ -eq "SemVer" } { "#.#.#.B" } { "#.#.#.#" }
    }
    if(-not $FileVersionPattern) {
        $FileVersionPattern = $versionData.Type | ?: { $_ -eq "SemVer" } { "#.#.#.B" } { "#.#.#.#" }
    }
    if(-not $ProductVersionPattern) {
        $ProductVersionPattern = $versionData.Type | ?: { $_ -eq "SemVer" } { "#.#.###" } { "#.#.#.#" }
    }
    if(-not $PackageVersionPattern) {
        $PackageVersionPattern = $versionData.Type | ?: { $_ -eq "SemVer" } { "#.#.###" } { "#.#.#.#" }
    }

    $assemblyVersion = Format-Version -VersionData $versionData -VersionFormat $AssemblyVersionPattern
    $fileVersion = Format-Version -VersionData $versionData -VersionFormat $FileVersionPattern
    $productVersion = Format-Version -VersionData $versionData -VersionFormat $ProductVersionPattern
    $packageVersion = Format-Version -VersionData $versionData -VersionFormat $PackageVersionPattern -NuGetPackageVersion

    Write-Verbose "AssemblyVersion: $assemblyVersion"
    Write-Verbose "FileVersion: $fileVersion"
    Write-Verbose "ProductVersion: $productVersion"
    Write-Verbose "PackageVersion: $packageVersion"

    $regex = @{
        ".cs" = @{
            AssemblyVersion = '\[\s*assembly\s*:\s*AssemblyVersion(Attribute)?\s*\(\s*\"(?<version>[^"]*)\"\s*\)\s*\]'
            FileVersion = '\[\s*assembly\s*:\s*AssemblyFileVersion(Attribute)?\s*\(\s*\"(?<version>[^"]*)\"\s*\)\s*\]'
            productVersion = '\[\s*assembly\s*:\s*AssemblyInformationalVersion(Attribute)?\s*\(\s*\"(?<version>[^"]*)\"\s*\)\s*\]'
        }
        ".vb" = @{
            AssemblyVersion = '<\s*assembly\s*:\s*AssemblyVersion(Attribute)?\s*\(\s*\"(?<version>[^"]*)\"\s*\)\s*>'
            FileVersion = '<\s*assembly\s*:\s*AssemblyFileVersion(Attribute)?\s*\(\s*\"(?<version>[^"]*)\"\s*\)\s*>'
            ProductVersion = '<\s*assembly\s*:\s*AssemblyInformationalVersion(Attribute)?\s*\(\s*\"(?<version>[^"]*)\"\s*\)\s*>'
        }
        ".cpp" = @{
            AssemblyVersion = '\[\s*assembly\s*:\s*AssemblyVersion(Attribute)?\s*\(\s*\"(?<version>[^"]*)\"\s*\)\s*\]'
            FileVersion = '\[\s*assembly\s*:\s*AssemblyFileVersion(Attribute)?\s*\(\s*\"(?<version>[^"]*)\"\s*\)\s*\]'
            ProductVersion = '\[\s*assembly\s*:\s*AssemblyInformationalVersion(Attribute)?\s*\(\s*\"(?<version>[^"]*)\"\s*\)\s*\]'
        }
        ".fs" = @{
            AssemblyVersion = '\[<\s*assembly\s*:\s*AssemblyVersion(Attribute)?\s*\(\s*\"(?<version>[^"]*)\"\s*\)\s*>\]'
            FileVersion = '\[<\s*assembly\s*:\s*AssemblyFileVersion(Attribute)?\s*\(\s*\"(?<version>[^"]*)\"\s*\)\s*>\]'
            ProductVersion = '\[<\s*assembly\s*:\s*AssemblyInformationalVersion(Attribute)?\s*\(\s*\"(?<version>[^"]*)\"\s*\)\s*>\]'
        }
    }
    $format = @{
        ".cs" = @{
            AssemblyVersion = "[assembly: AssemblyVersion(""{0}"")]"
            FileVersion = "[assembly: AssemblyFileVersion(""{0}"")]"
            ProductVersion = "[assembly: AssemblyInformationalVersion(""{0}"")]"
        }
        ".vb" = @{
            AssemblyVersion = "<Assembly: AssemblyVersion(""{0}"")>"
            FileVersion = "<Assembly: AssemblyFileVersion(""{0}"")>"
            ProductVersion = "<Assembly: AssemblyInformationalVersion(""{0}"")>"
        }
        ".cpp" = @{
            AssemblyVersion = "[assembly: AssemblyVersionAttribute(""{0}"")]"
            FileVersion = "[assembly: AssemblyFileVersionAttribute(""{0}"")]"
            ProductVersion = "[assembly: AssemblyInformationalVersionAttribute(""{0}"")]"
        }
        ".fs" = @{
            AssemblyVersion = "[<assembly: AssemblyVersion(""{0}"")>]"
            FileVersion = "[<assembly: AssemblyFileVersion(""{0}"")>]"
            ProductVersion = "[<assembly: AssemblyInformationalVersion(""{0}"")>]"
        }
    }

    # find the files containing the version-attributes
    $files = @()
    $files += Get-ChildItem -Path $sourcesDirectory -Recurse -Include $AssemblyVersionFilePattern
    $files += Get-ChildItem -Path $sourcesDirectory -Recurse -Include "*.nuspec"

    # apply the version to the assembly property-files
    if($files) {
        Write-Verbose "Will apply $assemblyFileVersion to $($files.count) files."

        foreach ($file in $files) {
            if (-not $WhatIf) {
                $fileContent = Get-Content($file)
                #attrib $file -r
				Set-ItemProperty -Path $file -Name IsReadOnly -Value $false

                $fileExtension = $file.Extension.ToLowerInvariant()
                if ($fileExtension -eq ".nuspec") {
                    [xml]$fileContent = Get-Content -Path $file

                    $fileContent.package.metadata.version = $packageVersion

					foreach ($dependency in $fileContent.package.metadata.dependencies.ChildNodes) {
						if ($dependency.version -match "{version}") {
							$dependency.version = $dependency.version -replace "{version}", $packageVersion
						}
					}

                    $fileContent.Save($file)
                }
                else {
                    if (-not ($regex.ContainsKey($fileExtension) -and $format.ContainsKey($fileExtension))) {
                        throw "'$($file.Extension)' is not one of the accepted file types (.cs, .vb, .cpp, .fs)."
                    }

                    $fileContent = $fileContent -replace $regex[$fileExtension].AssemblyVersion, ($format[$fileExtension].AssemblyVersion -f $assemblyVersion)
                    $fileContent = $fileContent -replace $regex[$fileExtension].FileVersion, ($format[$fileExtension].FileVersion -f $fileVersion)
                    $fileContent = $fileContent -replace $regex[$fileExtension].ProductVersion, ($format[$fileExtension].ProductVersion -f $productVersion)

                    $fileContent | Out-File $file
                }

                Write-Verbose "$($file.FullName) - version applied"
            }
            else {
                Write-Verbose "$($file.FullName) - version would have been applied"
            }
        }
    }
    else {
        Write-Warning "No files found."
    }
}

$sourcesDirectory = $env:BUILD_SOURCESDIRECTORY
$buildNumber = $env:BUILD_BUILDNUMBER

if (-not $Disabled) {
    Update-Version -SourcesDirectory $sourcesDirectory `
                   -BuildNumber $buildNumber `
				   -Version $Version `
                   -AssemblyVersionFilePattern $AssemblyVersionFilePattern `
                   -AssemblyVersionPattern $AssemblyVersionPattern `
                   -FileVersionPattern $FileVersionPattern `
                   -ProductVersionPattern $ProductVersionPattern `
				   -PackageVersionPattern $PackageVersionPattern `
                   -Verbose:$VerbosePreference
}
else {
    Write-Verbose "Script disabled; update of version skipped"
}
