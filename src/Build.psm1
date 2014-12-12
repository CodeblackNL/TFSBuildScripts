##-----------------------------------------------------------------------
## <copyright file="Build.psm1">(c) https://github.com/CodeblackNL/TFSBuildScripts. See https://github.com/CodeblackNL/TFSBuildScripts/blob/master/LICENSE. </copyright>
##-----------------------------------------------------------------------
<#
.SYNOPSIS
    Module containing common functions for use in TFS builds.
.DESCRIPTION
    Module containing common functions for use in TFS builds.

    Author: Jeroen Swart
    Versions:
    - 1.0.0  11-11-2014  Initial version; includes Update-Version
    - 1.1.0  05-12-2014  Added Invoke-SonarRunner & Remove-BOM
    - 1.2.0  07-12-2014  Added package versioning to Update-Version
    - 1.2.1  10-12-2014  Fix package versioning for NuGet; it does not fully support SemVer
    - 1.3.0  12-12-2014  Added package packaging & publishing
#>

set-alias ?: Invoke-Ternary -Option AllScope -Description "PSCX filter alias"
filter Invoke-Ternary ([scriptblock]$decider, [scriptblock]$ifTrue, [scriptblock]$ifFalse) 
{
    if (& $decider) { 
        & $ifTrue
    } else { 
        & $ifFalse 
    }
}

function Get-EnvironmentVariable {
<#
    .SYNOPSIS
        Retrieves an environment-variable.
    .DESCRIPTION
        Retrieves an environment-variable.

    .PARAMETER  Name
        Defines the name of the environment-variable to retrieve.

    .EXAMPLE
        Get-EnvironmentVariable -Name "TF_BUILD_BUILDNUMBER"
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $parameterValue = (Get-ChildItem Env: | ?{ $_.Name -eq $Name }).Value

    Write-Verbose "$($Name): $parameterValue"

    return $parameterValue
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
            $version = $version -creplace '\.BB', ".$Rev"
        }
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
        # process version-formatting ('YYYY','YY','M','D','B','J')
        $revMatch = [regex]::match($BuildNumber, '\d+$')
        if ($revMatch.Success) {
            $rev = $revMatch.Groups[0].Value
        }
        $Version = Format-Version -VersionFormat $Version -Rev $rev

        # get version-data from the provided version
        $versionData = Get-VersionData -VersionString $Version
    }

    # determine default version-patterns, based on the type of version used, for those that are not provided
    # assembly-version & file-version do not support SemVer, so use #.#.#.0 pattern
    if(-not $AssemblyVersionPattern) {
        $AssemblyVersionPattern = $versionData.Type | ?: { $_ -eq "SemVer" } { "#.#.#.0" } { "#.#.#.#" }
    }
    if(-not $FileVersionPattern) {
        $FileVersionPattern = $versionData.Type | ?: { $_ -eq "SemVer" } { "#.#.#.0" } { "#.#.#.#" }
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
                attrib $file -r

                $fileExtension = $file.Extension.ToLowerInvariant()
                if ($fileExtension -eq ".nuspec") {
                    [xml]$fileContent = Get-Content -Path $file

                    $fileContent.package.metadata.version = $packageVersion

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

function Remove-BOM {
<#
    .SYNOPSIS
        Removes the BOM (Byte Order Mark) from the specified files.
    .DESCRIPTION
        Removes the BOM (Byte Order Mark) from the specified files.

    .PARAMETER  Directory
        Specifies the directory in which to look for files.
    .PARAMETER  SearchPattern
        Specifies the pattern to use when looking for files. Default is '"*.cs","*.vb"'.
    .PARAMETER  WhatIf
        Specifies that no changes should be made.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Directory,
        [Parameter(Mandatory = $false)]
        [string[]]$SearchPattern = @("*.cs","*.vb"),
        [Parameter(Mandatory = $false)]
        [switch]$WhatIf = $false
    )

    $files = Get-ChildItem $Directory -Include $SearchPattern -Recurse
    foreach ($file in $files) {
        Write-Verbose "Removing BOM from '$($file.FullName)'."
        if (-not $WhatIf) {
            Set-ItemProperty $file.FullName -name IsReadOnly -value $false
    
            $content = Get-Content $file.FullName
            [System.IO.File]::WriteAllLines($file.FullName, $content)
        }
    }
}

function Invoke-Process {
<#
    .SYNOPSIS
        Starts a process.
    .DESCRIPTION
        Starts a process using the specified file-path and working-directory.

    .PARAMETER  FilePath
        Specifies the file-path of the application file to run in the process.
    .PARAMETER  WorkingDirectory
        Specifies the working-directory for the new process.
    .PARAMETER  Arguments
        Specifies the arguments for the new process.
#>
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory,
        [Parameter(Mandatory = $false)]
        [string]$Arguments
    )

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    $process.StartInfo.UseShellExecute = $false

    $process.StartInfo.Filename = $FilePath
    $process.StartInfo.WorkingDirectory = $WorkingDirectory
    $process.StartInfo.Arguments = $Arguments

    $started = $process.start()
        
    while (-not $process.HasExited) {
        $output = $process.StandardOutput.ReadToEnd()
        Write-Verbose $output
    }

    $error = $process.StandardError.ReadToEnd();
    if ($error) {
        Write-Error $error
    }
}

function Invoke-SonarRunner {
<#
    .SYNOPSIS
        Runs the sonar analysis.
    .DESCRIPTION
        Runs the sonar analysis.

    .PARAMETER  SourcesDirectory
        Specifies the root-directory containing the source-files.
    .PARAMETER  SonarRunnerBinDirectory
        Specifies the directory containing the sonar-runner binaries. Default is 'C:\sonar\bin'.
    .PARAMETER  SonarPropertiesFileName
        Specifies the file-name of the sonar-properties file. Default is 'sonar-project.properties'.
    .PARAMETER  WhatIf
        Specifies that no changes should be made.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SourcesDirectory,
        [Parameter(Mandatory = $false)]
        [string]$SonarRunnerBinDirectory,
        [Parameter(Mandatory = $false)]
        [string]$SonarPropertiesFileName,
        [Parameter(Mandatory = $false)]
        [switch]$WhatIf = $false
    )

    if (-not $SonarRunnerBinDirectory) {
        $SonarRunnerBinDirectory = "C:\sonar\bin"
        Write-Verbose "SonarRunnerBinDirectory not provided, using default '$SonarRunnerBinDirectory'"
    }

    if (-not $SonarPropertiesFileName) {
        $SonarPropertiesFileName = "sonar-project.properties"
        Write-Verbose "SonarPropertiesFileName not provided, using default '$SonarPropertiesFileName'"
    }

    $SonarRunnerBinPath = Join-Path $SonarRunnerBinDirectory "sonar-runner.bat"
    Write-Verbose "Using sonar-runner path '$SonarRunnerBinPath'"

    $SonarPropertiesFilePath = Join-Path $SourcesDirectory $SonarPropertiesFileName
    Write-Verbose "Using sonar project-configuration path '$SonarPropertiesFilePath'"

    if (-not (Test-Path $SonarRunnerBinPath)) {
        Write-Verbose "Sonar-sunner not installed"
        return
    }

    if (-not (Test-Path $SonarPropertiesFilePath)) {
        Write-Verbose "Sonar project-configuration not found, Sonar analysis skipped"
        return
    }

    if (-not $WhatIf) {
        Invoke-Process -FilePath $SonarRunnerBinPath -WorkingDirectory $SourcesDirectory
    }
    else {
        Write-Verbose "What if..., analysis skipped"
    }
}

function Get-Build {
<#
    .SYNOPSIS
        Retrieves the details for a specific build.
    .DESCRIPTION
        Retrieves the details for a specific build.

    .PARAMETER  CollectionUri
        Specifies the uri of the team-project-collection to retrieve the build-details from.
    .PARAMETER  BuildUri
        Specifies the uri of the build.
#>
    param (
        [Parameter(Mandatory = $true)]
        [string]$CollectionUri,
        [Parameter(Mandatory = $true)]
        [string]$BuildUri
    )

    [Reflection.Assembly]::LoadWithPartialName('Microsoft.TeamFoundation.Client') | Out-Null
    [Reflection.Assembly]::LoadWithPartialName('Microsoft.TeamFoundation.Build.Client') | Out-Null

    $teamProjectCollection = [Microsoft.TeamFoundation.Client.TfsTeamProjectCollectionFactory]::GetTeamProjectCollection($CollectionUri)
    $buildServer = $teamProjectCollection.GetService([Microsoft.TeamFoundation.Build.Client.IBuildServer])
    
    return $buildServer.GetBuild($BuildUri);
}

function Get-NuGetFilePath {
<#
    .SYNOPSIS
        Retrieves the full-path of 'nuget.exe'.
    .DESCRIPTION
        Retrieves the full-path of 'nuget.exe'.
        First looks in each specified directory, then does a recursive search in each specified directory.

    .PARAMETER  Directory
        Specifies one or more directories to look for 'nuget.exe'.
#>
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$Directory
    )

    $nugetFileName = "nuget.exe"

    foreach ($dir in $Directory) {
        $nugetPath = Join-Path $dir $nugetFileName
        if (Test-Path $nugetPath) {
            return $nugetPath
        }
    }

    foreach ($dir in $Directory) {
        $nugetPath = (Get-ChildItem -Path $dir -Filter "nuget.exe" -Recurse | Sort { ([System.Diagnostics.FileVersionInfo]::GetVersionInfo($_.FullName).FileVersion) } -Descending | Select -First 1).FullName
        if ($nugetPath -and (Test-Path $nugetPath)) {
            return $nugetPath
        }
    }
}

function New-NuGetPackage {
<#
    .SYNOPSIS
        Creates new NuGet-packages according to the specified nuspec-files.
    .DESCRIPTION
        Creates new NuGet-packages according to the specified nuspec-files.

    .PARAMETER  SourcesDirectory
        Specifies the root-directory containing the source-files.
    .PARAMETER  BinariesDirectory
        Specifies the root-directory containing the source-files.
    .PARAMETER  DropDirectory
        Specifies the drop-directory containing the results of the build.
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
    .PARAMETER  WhatIf
        Specifies that no changes should be made.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SourcesDirectory,
        [Parameter(Mandatory = $true)]
        [string]$BinariesDirectory,
        [Parameter(Mandatory = $true)]
        [string]$DropDirectory,
        [Parameter(Mandatory = $false)]
        [string[]]$NuspecFilePath,
        [Parameter(Mandatory = $false)]
        [string]$BasePath,
        [Parameter(Mandatory = $false)]
        [string]$OutputPath,
        [Parameter(Mandatory = $false)]
        [string]$AdditionalPackOptions,
        [Parameter(Mandatory = $false)]
        [switch]$WhatIf = $false
    )

    if ($BasePath) {
        $BasePath = $BasePath.Trim()
    }
    if ($OutputPath) {
        $OutputPath = $OutputPath.Trim()
    }

    if (-not $OutputPath) {
        $OutputPath = "Package"
    }

    # check if the drop-directory is available and files are already copied there
    if ((Test-Path $DropDirectory) -and (Get-ChildItem $DropDirectory | ?{ -not $_.PSIsContainer }).Count -gt 0) {
        # if this function is called from the post-execution script, the drop-directory will be populated
        # in which case, use the drop-directory
        $fullBasePath = (Join-Path $DropDirectory $BasePath).TrimEnd('\')
    }
    else {
        # if this function is called from the post-test script, the drop-directory will be empty (if it exists at all)
        # in which case, use the binaries-directory
        $fullBasePath = (Join-Path $BinariesDirectory $BasePath).TrimEnd('\')

        # if the resulting path doesn't exist, e.g. when using a pre-packaging folder
        # use the drop-directory instead; it will be populated, from the binaries-directory, by the pre-package script
        if (-not (Test-Path $fullBasePath)) {
            $fullBasePath = (Join-Path $DropDirectory $BasePath).TrimEnd('\')
        }
    }
	if (-not (Test-Path $fullBasePath)) {
		New-Item $fullBasePath -ItemType Container -ErrorAction SilentlyContinue | Out-Null
	}

    $fullOutputPath = (Join-Path $DropDirectory $OutputPath).TrimEnd('\')
	if (-not (Test-Path $fullOutputPath)) {
		New-Item $fullOutputPath -ItemType Container -ErrorAction SilentlyContinue | Out-Null
	}

    $nuspecFilePaths = @()

    if ($NuspecFilePath) {
        foreach ($path in $NuspecFilePath) {
            $fullPath = Join-Path $SourcesDirectory $path
            if (Test-Path $fullPath) {
                $nuspecFilePaths += $fullPath
            }
        }
    }
    else {
        $nuspecFilePaths += (Get-ChildItem -Path $SourcesDirectory -Include "*.nuspec" -Recurse).FullName
    }

    if ($nuspecFilePaths) {
        foreach ($path in $nuspecFilePaths) {
            Write-Verbose "Creating package for '$path'"

			[xml]$nuspecContent = Get-Content -Path $Path
			$version = $nuspecContent.package.metadata.version

            $scriptFileName = "$([System.IO.Path]::GetFileNameWithoutExtension($path)).ps1"
            $scriptPath = Join-Path (Split-Path $path) $scriptFileName

            if (Test-Path $scriptPath) {
                Write-Verbose "Executing pre-package script '$scriptPath'"

		        if (-not $WhatIf) {
					try {
						& $scriptPath $SourcesDirectory $BinariesDirectory $DropDirectory $fullBasePath
					}
					catch {
						Write-Error "Error executing pre-package script for '$path'"
						Write-Error $_
					}
	            }
				else {
					Write-Verbose "What if..., pre-package script execution skipped"
				}
            }

            $nugetFilePath = Get-NuGetFilePath (Split-Path $path),$PSScriptRoot,$SourcesDirectory
            Write-Verbose "Using '$nugetFilePath'"

            if ($nugetFilePath) {
                $arguments = "pack `"$path`" -BasePath `"$fullBasePath`" -OutputDirectory `"$fullOutputPath`" $AdditionalPackOptions"
                if ($VerbosePreference -eq "Continue" -and -not ($arguments -like "*-Verbosity*")) {
                    $arguments += " -Verbosity Detailed"
                }
                Write-Verbose "With arguments '$arguments'"

	            if (-not $WhatIf) {
                    Invoke-Process -FilePath $nugetFilePath `
                                    -WorkingDirectory $fullBasePath `
                                    -Arguments $arguments

                    ConvertTo-Json @{
                        NuspecFilePath = $path
                        NugetFilePath = $nugetFilePath
                    } | Out-File (Join-Path $fullOutputPath "$([System.IO.Path]::GetFileNameWithoutExtension($path)).$version.json")
			    }
			    else {
				    Write-Verbose "What if..., packaging skipped"
			    }
            }
            else {
                Write-Error "'nuget.exe' is missing. Please add it to the location of the nuspec-file or build-scripts."
            }

        }
    }
    else {
        Write-Verbose "No nuspec-files found"
    }
}

function Push-NuGetPackage {
<#
    .SYNOPSIS
        Creates new NuGet-packages according to the specified nuspec-files.
    .DESCRIPTION
        Creates new NuGet-packages according to the specified nuspec-files.

    .PARAMETER  DropDirectory
        Specifies the drop-directory containing the results of the build.
    .PARAMETER  OutputPath
        Specifies the path to use as the output-path for the package(s), relative to the drop-directory.
        Default is 'Package'.
    .PARAMETER	Source
        Specifies the package-source to push the package(s) to.
    .PARAMETER	ApiKey
        Specifies the API-key to use when pushing the package(s).
    .PARAMETER  WhatIf
        Specifies that no changes should be made.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$DropDirectory,
        [Parameter(Mandatory = $false)]
        [string]$OutputPath,
        [Parameter(Mandatory = $false)]
        [string]$Source,
        [Parameter(Mandatory = $false)]
        [string]$ApiKey,
        [Parameter(Mandatory = $false)]
        [switch]$WhatIf = $false
    )

    if ($Source) {
        $Source = $Source.Trim()
    }
    if ($OutputPath) {
        $OutputPath = $OutputPath.Trim()
    }

    if (-not $Source) {
        Write-Verbose "No source provided, pushing skipped"
        return
	}

    if (-not $OutputPath) {
        $OutputPath = "Package"
    }

    $fullOutputPath = Join-Path $DropDirectory $OutputPath

    $nupkgFilePaths = (Get-ChildItem -Path $fullOutputPath -Include "*.nupkg" -Recurse).FullName
    foreach ($nupkgFilePath in $nupkgFilePaths) {
        Write-Verbose "Pushing package '$nupkgFilePath' to '$Source'"

        try {
            $dataFileName = "$([System.IO.Path]::GetFileNameWithoutExtension($nupkgFilePath)).json"
            $dataFilePath = Join-Path (Split-Path $nupkgFilePath) $dataFileName
			if (Test-Path $dataFilePath) {
				$data = ConvertFrom-Json (Get-Content $dataFilePath -Raw)

				$nugetFilePath = $data.NugetFilePath
				if ($nugetFilePath) {
					Write-Verbose "Using '$nugetFilePath'"

					$arguments = "push `"$nupkgFilePath`" $ApiKey -Source `"$Source`""
                    if ($VerbosePreference -eq "Continue") {
                        $arguments += " -Verbosity Detailed"
                    }
					Write-Verbose "With arguments '$arguments'"

					if (-not $WhatIf) {
						Invoke-Process -FilePath $nugetFilePath `
									   -WorkingDirectory $fullOutputPath `
									   -Arguments $arguments
					}
				}
			}
	        else {
	            Write-Verbose "Unable to load data-file for package '$nupkgFilePath', pushing of package skipped"
	        }
        }
        catch {
            Write-Error "Failure while pushing package '$nupkgFilePath' to '$Source'"
            Write-Error $_
        }
    }
}

Export-ModuleMember -Function Get-EnvironmentVariable
Export-ModuleMember -Function Update-Version
Export-ModuleMember -Function Remove-BOM
Export-ModuleMember -Function Invoke-SonarRunner
Export-ModuleMember -Function Get-Build
Export-ModuleMember -Function New-NuGetPackage
Export-ModuleMember -Function Push-NuGetPackage
