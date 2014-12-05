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
    .PARAMETER  $ProductVersionPattern
        Specifies the version, or pattern, for the assembly-informational-version.
        Depending on the provided version (either through the Version or BuildNumber parameters)
        the default is '#.#.#.#' (.NET) or '#.#.#.0' (SemVer).
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
            [int]$Rev
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

    $assemblyVersion = Format-Version -VersionData $versionData -VersionFormat $AssemblyVersionPattern
    $fileVersion = Format-Version -VersionData $versionData -VersionFormat $FileVersionPattern
    $productVersion = Format-Version -VersionData $versionData -VersionFormat $ProductVersionPattern

    Write-Verbose "AssemblyVersion: $assemblyVersion"
    Write-Verbose "FileVersion: $fileVersion"
    Write-Verbose "ProductVersion: $productVersion"

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
    $files = Get-ChildItem -Path $sourcesDirectory -Recurse -Include $AssemblyVersionFilePattern

    # apply the version to the assembly property-files
    if($files) {
        Write-Verbose "Will apply $assemblyFileVersion to $($files.count) files."

        foreach ($file in $files) {
            if (-not $WhatIf) {
                $fileContent = Get-Content($file)
                attrib $file -r

                $fileExtension = $file.Extension.ToLowerInvariant()

                if (-not ($regex.ContainsKey($fileExtension) -and $format.ContainsKey($fileExtension))) {
                    throw "'$($file.Extension)' is not one of the accepted file types (.cs, .vb, .cpp, .fs)."
                }

                $fileContent = $fileContent -replace $regex[$fileExtension].AssemblyVersion, ($format[$fileExtension].AssemblyVersion -f $assemblyVersion)
                $fileContent = $fileContent -replace $regex[$fileExtension].FileVersion, ($format[$fileExtension].FileVersion -f $fileVersion)
                $fileContent = $fileContent -replace $regex[$fileExtension].ProductVersion, ($format[$fileExtension].ProductVersion -f $productVersion)

                $fileContent | Out-File $file

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

function Invoke-SonarRunner {
<#
    .SYNOPSIS
        Runs the sonar analysis.
    .DESCRIPTION
        Runs the sonar analysis.

    .PARAMETER  $SourcesDirectory
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

    if (-not (Test-Path $SonarPropertiesFilePath)) {
        Write-Verbose "Sonar project-configuration not found, Sonar analysis skipped"
        return
    }

    if (-not (Test-Path $SonarRunnerBinPath)) {
        Write-Verbose "Sonar-sunner not installed"
        return
    }

    if (-not $WhatIf) {
        $sonar = New-Object System.Diagnostics.Process
        $sonar.StartInfo.Filename = $SonarRunnerBinPath
        $sonar.StartInfo.WorkingDirectory = $SourcesDirectory
        $sonar.StartInfo.RedirectStandardOutput = $true
        $sonar.StartInfo.RedirectStandardError = $true
        $sonar.StartInfo.UseShellExecute = $false
        $started = $sonar.start()
        Write-Verbose "Sonar-runner started: '$started'"
        
		while (-not $sonar.HasExited) {
			$output = $sonar.StandardOutput.ReadToEnd()
	        Write-Verbose $output
		}

        $error = $sonar.StandardError.ReadToEnd();
        if ($error) {
            Write-Error $error
        }
    }
    else {
        Write-Verbose "What if..., analysis skipped"
    }
}
