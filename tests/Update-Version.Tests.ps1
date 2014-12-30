##-----------------------------------------------------------------------
## <copyright file="Update-Version.Tests.ps1">(c) https://github.com/CodeblackNL/TFSBuildScripts. See https://github.com/CodeblackNL/TFSBuildScripts/blob/master/LICENSE. </copyright>
##-----------------------------------------------------------------------

Remove-Module "Build" -ErrorAction SilentlyContinue
Import-Module "$PSScriptRoot\..\src\Build.psm1"

$AssemblyInfo_CS = @'
// here comes the assembly-version
[assembly: AssemblyVersion("1.0.0.0")]

// and here the file-version
[assembly: AssemblyFileVersion("1.0.0.0")]
// ...

// and finally the product-version
[assembly: AssemblyInformationalVersion("1.0.0.0")]
// ...

// the end.
'@
$Package_Nuspec = @'
<?xml version="1.0"?>
<package>
  <metadata>
    <id>VersionTest</id>
    <version>999.999.999</version>
    <authors>Jeroen Swart</authors>
    <description>VersionTest.</description>
  </metadata>
</package>
'@

function Get-Version {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [ValidateSet("AssemblyVersion", "FileVersion", "ProductVersion", IgnoreCase = $true)]
        [string]$VersionType
    )

    if (!(Test-Path $Path)) {
        throw "File '$Path' does not exist."    
    }

	switch ($VersionType.ToLower()) {
		"assemblyversion" {
			$pattern = '\[\s*assembly\s*:\s*AssemblyVersion(Attribute)?\s*\(\s*\"(?<version>[^"]*)\"\s*\)\s*\]'
		}
		"fileversion" {
			$pattern = '\[\s*assembly\s*:\s*AssemblyFileVersion(Attribute)?\s*\(\s*\"(?<version>[^"]*)\"\s*\)\s*\]'
		}
		"productversion" {
			$pattern = '\[\s*assembly\s*:\s*AssemblyInformationalVersion(Attribute)?\s*\(\s*\"(?<version>[^"]*)\"\s*\)\s*\]'
		}
	}
    
	$content = Get-Content -Path $Path

	$version = $content | ?{ $_ -match $pattern } | %{ $Matches['version'] }
	if (-not $version) {
		throw "Requested version-attribute not found in '$Path'."
	}

    return $version
}

function Get-PackageVersion {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (!(Test-Path $Path)) {
        throw "File '$Path' does not exist."    
    }

	try {
		[xml]$content = Get-Content -Path $Path

		$version = $content.package.metadata.version
	}
	catch { }

    return $version
}

Describe "Update-Version" {
    Context "when version is explicitly provided in .NET format" {
        $buildNumber = "Test_2014-11-27"
        $path = "TestDrive:\AssemblyInfo.cs"
        $nuspecPath = "TestDrive:\package.nuspec"
        $expectedVersion = "2.3.1.4"

        Set-Content -Path $path -Value $AssemblyInfo_CS
        Set-Content -Path $nuspecPath -Value $Package_Nuspec

        It "should use this version for the assembly-version" {
            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $expectedVersion -AssemblyVersionPattern "#.#.#.#"

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should use this version for the file-version" {
            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $expectedVersion -FileVersionPattern "#.#.#.#"

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should use this version for the product-version" {
            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $expectedVersion -ProductVersionPattern "#.#.#.#"

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should use this version for the package-version" {
            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $expectedVersion -PackageVersionPattern "#.#.#.#"

            $actualVersion = Get-PackageVersion -Path $nuspecPath
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context "when version is explicitly provided in SemVer format" {
        $buildNumber = "Test_2014-11-27"
        $path = "TestDrive:\AssemblyInfo.cs"
        $nuspecPath = "TestDrive:\package.nuspec"
        $version = "2.3.1-ci42+12345.0"

        Set-Content -Path $path -Value $AssemblyInfo_CS
        Set-Content -Path $nuspecPath -Value $Package_Nuspec

        It "should use this version for the assembly-version" {
            # assembly-version does not support SemVer, so use #.#.#.0 pattern
            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -AssemblyVersionPattern "#.#.#.0"

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be "2.3.1.0"
        }

        It "should use this version for the file-version" {
            # assembly-version does not support SemVer, so use #.#.#.0 pattern
            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -FileVersionPattern "#.#.#.0"

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be "2.3.1.0"
        }

        It "should use this version for the product-version" {
            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -ProductVersionPattern "#.#.###"

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be "2.3.1-ci42+12345.0"
        }

        It "should use this version for the package-version" {
            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -PackageVersionPattern "#.#.###"

            # NuGet does not fully support SemVer, so '.' & '+' are replaced with '-'
            $actualVersion = Get-PackageVersion -Path $nuspecPath
            $actualVersion | Should Be "2.3.1-ci42-12345-0"
        }
    }

    Context "when version is explicitely provided with formatting" {
        # NOTE: since only the product-version allows all versioning-patterns,
        #       the version-patterns in this context are only tested against the product-version;
        #       it is assumed (for now) that these patterns will work for the other versions as well
        $buildNumber = "Test_2014-11-27_2.3.1.7"
        $path = "TestDrive:\AssemblyInfo.cs"

        Set-Content -Path $path -Value $AssemblyInfo_CS

        It "should return correct version when pattern is '1.2.J.B'" {
            $versionPattern = "1.2.J.B"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.$julian.7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is 'YYYY.M.D.B'" {
            $versionPattern = "YYYY.M.D.B"
            $now = [DateTime]::Now
            $expectedVersion = "$($now.Year).$($now.Month).$($now.Day).7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is 'YYYY.MM.DD.BB'" {
            $versionPattern = "YYYY.MM.DD.BB"
            $now = [DateTime]::Now
            $expectedVersion = "$($now.Year).$($now.Month).$($now.Day).7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is 'YYYY.MM.DD.BBB'" {
            $versionPattern = "YYYY.MM.DD.BBB"
            $now = [DateTime]::Now
            $expectedVersion = "$($now.Year).$($now.Month).$($now.Day).7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.YY.MMDD.B'" {
            $versionPattern = "1.YY.MMDD.B"
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month)$($now.Day.ToString("00")).7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.YY.MD.B'" {
            $buildNumber = "Test_2014-11-27_2.3.1.8"
            $versionPattern = "1.YY.MD.B"
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month)$($now.Day).8"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.YY.MM.DDBB'" {
            $versionPattern = "1.YY.MM.DDBB"
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month).$($now.Day)07"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.YY.MM.DDBBB'" {
            $versionPattern = "1.YY.MM.DDBBB"
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month).$($now.Day)007"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.2.3-ci+J.B'" {
            $versionPattern = "1.2.3-ci+J.B"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.3-ci+$julian.7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.2.3-ci+J.BB'" {
            $versionPattern = "1.2.3-ci+J.BB"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.3-ci+$julian.07"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.2.3-ci+J.BBB'" {
            $versionPattern = "1.2.3-ci+J.BBB"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.3-ci+$julian.007"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.2.3-ciJ-B'" {
            $versionPattern = "1.2.3-ciJ-B"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.3-ci$julian-7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.2.3-ciJ-BB'" {
            $versionPattern = "1.2.3-ciJ-BB"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.3-ci$julian-07"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.2.3-ciJ-BBB'" {
            $versionPattern = "1.2.3-ciJ-BBB"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.3-ci$julian-007"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '#.#.#.#'" {
            $versionPattern = "#.#.#.#"
            $expectedVersion = "2.3.1.7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '#.#.#.0'" {
            $versionPattern = "#.#.#.0"
            $expectedVersion = "2.3.1.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '#.#.0.0'" {
            $versionPattern = "#.#.0.0"
            $expectedVersion = "2.3.0.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '#.0.0.0'" {
            $versionPattern = "#.0.0.0"
            $expectedVersion = "2.0.0.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '#.#.#.B'" {
            $versionPattern = "#.#.#.B"
            $expectedVersion = "2.3.1.7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '#.#.#.100B'" {
            $versionPattern = "#.#.#.100B"
            $expectedVersion = "2.3.1.1007"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '#.#.#.10BB'" {
            $versionPattern = "#.#.#.10BB"
            $expectedVersion = "2.3.1.1007"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '#.#.#.1BBB'" {
            $versionPattern = "#.#.#.1BBB"
            $expectedVersion = "2.3.1.1007"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context "when version is in the build-number in .NET format" {
        $buildNumber = "Test_2014-11-27_3.2.12345.7"
        $path = "TestDrive:\AssemblyInfo.cs"
        $nuspecPath = "TestDrive:\package.nuspec"
        $expectedVersion = "3.2.12345.7"

        Set-Content -Path $path -Value $AssemblyInfo_CS
        Set-Content -Path $nuspecPath -Value $Package_Nuspec

        It "should use this version for the assembly-version" {
            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -AssemblyVersionPattern "#.#.#.#"

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should use this version for the file-version" {
            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -FileVersionPattern "#.#.#.#"

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should use this version for the product-version" {
            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -ProductVersionPattern "#.#.#.#"

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should use this version for the package-version" {
            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -PackageVersionPattern "#.#.#.#"

            $actualVersion = Get-PackageVersion -Path $nuspecPath
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context "when version is in the build-number in SemVer format" {
        $buildNumber = "Test_2014-11-27_2.3.1-ci42+12345.07"
        $path = "TestDrive:\AssemblyInfo.cs"
        $nuspecPath = "TestDrive:\package.nuspec"

        Set-Content -Path $path -Value $AssemblyInfo_CS
        Set-Content -Path $nuspecPath -Value $Package_Nuspec

        It "should use this version for the assembly-version" {
            # assembly-version does not support SemVer, so use #.#.#.0 pattern
            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -AssemblyVersionPattern "#.#.#.0"

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be "2.3.1.0"
        }

        It "should use this version for the file-version" {
            # assembly-version does not support SemVer, so use #.#.#.0 pattern
            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -FileVersionPattern "#.#.#.0"

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be "2.3.1.0"
        }

        It "should use this version for the product-version" {
            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -ProductVersionPattern "#.#.###"

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be "2.3.1-ci42+12345.07"
        }

        It "should use this version for the package-version" {
            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -PackageVersionPattern "#.#.###"

            # NuGet does not fully support SemVer, so '.' & '+' are replaced with '-'
            $actualVersion = Get-PackageVersion -Path $nuspecPath
            $actualVersion | Should Be "2.3.1-ci42-12345-07"
        }
    }

    Context "when assembly-version is provided with formatting" {
        $buildNumber = "Test_2014-11-27_2.3.1.7"
        $path = "TestDrive:\AssemblyInfo.cs"

        Set-Content -Path $path -Value $AssemblyInfo_CS

        It "should return correct version when pattern is '1.2.J.B'" {
            $versionPattern = "1.2.J.B"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.$julian.7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is 'YYYY.M.D.B'" {
            $versionPattern = "YYYY.M.D.B"
            $now = [DateTime]::Now
            $expectedVersion = "$($now.Year).$($now.Month).$($now.Day).7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is 'YYYY.MM.DD.BB'" {
            $versionPattern = "YYYY.MM.DD.BB"
            $now = [DateTime]::Now
            $expectedVersion = "$($now.Year).$($now.Month).$($now.Day).7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is 'YYYY.MM.DD.BBB'" {
            $versionPattern = "YYYY.MM.DD.BBB"
            $now = [DateTime]::Now
            $expectedVersion = "$($now.Year).$($now.Month).$($now.Day).7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.YY.MMDD.B'" {
            $versionPattern = "1.YY.MMDD.B"
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month)$($now.Day.ToString("00")).7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.YY.MD.B'" {
            $buildNumber = "Test_2014-11-27_2.3.1.8"
            $versionPattern = "1.YY.MD.B"
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month)$($now.Day).8"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.YY.MM.DDBB'" {
            $versionPattern = "1.YY.MM.DDBB"
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month).$($now.Day)07"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.YY.MM.DDBBB'" {
            $versionPattern = "1.YY.MM.DDBBB"
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month).$($now.Day)007"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.2.3-ci+J.B'" {
            $versionPattern = "1.2.3-ci+J.B"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.3-ci+$julian.7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.2.3-ci+J.BB'" {
            $versionPattern = "1.2.3-ci+J.BB"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.3-ci+$julian.07"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.2.3-ci+J.BBB'" {
            $versionPattern = "1.2.3-ci+J.BBB"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.3-ci+$julian.007"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.2.3-ciJ-B'" {
            $versionPattern = "1.2.3-ciJ-B"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.3-ci$julian-7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.2.3-ciJ-BB'" {
            $versionPattern = "1.2.3-ciJ-BB"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.3-ci$julian-07"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.2.3-ciJ-BBB'" {
            $versionPattern = "1.2.3-ciJ-BBB"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.3-ci$julian-007"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context "when assembly-version is provided with #-tokens and using .NET format" {
        $buildNumber = "Test_2014-11-27_2.3.1.7"
        $path = "TestDrive:\AssemblyInfo.cs"
        $version = "1.2.3.4"

        Set-Content -Path $path -Value $AssemblyInfo_CS

        It "should return correct version when format is '#.#.#.#'" {
            $versionPattern = "#.#.#.#"
            $expectedVersion = "1.2.3.4"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#.#.0'" {
            $versionPattern = "#.#.#.0"
            $expectedVersion = "1.2.3.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#.0.0'" {
            $versionPattern = "#.#.0.0"
            $expectedVersion = "1.2.0.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.0.0.0'" {
            $versionPattern = "#.0.0.0"
            $expectedVersion = "1.0.0.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#.#'" {
            $versionPattern = "#.#.#"
            $expectedVersion = "1.2.3"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#.0'" {
            $versionPattern = "#.#.0"
            $expectedVersion = "1.2.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.0.0'" {
            $versionPattern = "#.0.0"
            $expectedVersion = "1.0.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#'" {
            $versionPattern = "#.#"
            $expectedVersion = "1.2"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.0'" {
            $versionPattern = "#.0"
            $expectedVersion = "1.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context "when assembly-version is provided with #-tokens and using SemVer format" {
        $buildNumber = "Test_2014-11-27"
        $path = "TestDrive:\AssemblyInfo.cs"
        $version = "1.2.3-ci0008+14331.07"

        Set-Content -Path $path -Value $AssemblyInfo_CS

        It "should return correct version when format is '#.#.###'" {
            $versionPattern = "#.#.###"
            $expectedVersion = "1.2.3-ci0008+14331.07"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#.##'" {
            $versionPattern = "#.#.##"
            $expectedVersion = "1.2.3-ci0008"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#.#'" {
            $versionPattern = "#.#.#"
            $expectedVersion = "1.2.3"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#.0'" {
            $versionPattern = "#.#.0"
            $expectedVersion = "1.2.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.0.0'" {
            $versionPattern = "#.0.0"
            $expectedVersion = "1.0.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context "when assembly-version contains placeholders" {
        $buildNumber = "Test_2014-11-27"
        $path = "TestDrive:\AssemblyInfo.cs"
        $version = "4.3.2.1"

        Set-Content -Path $path -Value $AssemblyInfo_CS

        It "should return single placeholder as is" {
            $versionPattern = "#.#.{0}"
            $expectedVersion = "4.3.{0}"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return multiple placeholder as is" {
            $versionPattern = "#.{1}#.{0}"
            $expectedVersion = "4.{1}3.{0}"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context "when file-version is provided with formatting" {
        $buildNumber = "Test_2014-11-27_2.3.1.7"
        $path = "TestDrive:\AssemblyInfo.cs"

        Set-Content -Path $path -Value $AssemblyInfo_CS

        It "should return correct version when pattern is '1.2.J.B'" {
            $versionPattern = "1.2.J.B"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.$julian.7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is 'YYYY.M.D.B'" {
            $versionPattern = "YYYY.M.D.B"
            $now = [DateTime]::Now
            $expectedVersion = "$($now.Year).$($now.Month).$($now.Day).7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is 'YYYY.MM.DD.BB'" {
            $versionPattern = "YYYY.MM.DD.BB"
            $now = [DateTime]::Now
            $expectedVersion = "$($now.Year).$($now.Month).$($now.Day).7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is 'YYYY.MM.DD.BBB'" {
            $versionPattern = "YYYY.MM.DD.BBB"
            $now = [DateTime]::Now
            $expectedVersion = "$($now.Year).$($now.Month).$($now.Day).7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.YY.MMDD.B'" {
            $versionPattern = "1.YY.MMDD.B"
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month)$($now.Day.ToString("00")).7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.YY.MD.B'" {
            $buildNumber = "Test_2014-11-27_2.3.1.8"
            $versionPattern = "1.YY.MD.B"
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month)$($now.Day).8"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.YY.MM.DDBB'" {
            $versionPattern = "1.YY.MM.DDBB"
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month).$($now.Day)07"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.YY.MM.DDBBB'" {
            $versionPattern = "1.YY.MM.DDBBB"
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month).$($now.Day)007"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.2.3-ci+J.B'" {
            $versionPattern = "1.2.3-ci+J.B"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.3-ci+$julian.7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.2.3-ci+J.BB'" {
            $versionPattern = "1.2.3-ci+J.BB"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.3-ci+$julian.07"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.2.3-ci+J.BBB'" {
            $versionPattern = "1.2.3-ci+J.BBB"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.3-ci+$julian.007"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.2.3-ciJ-B'" {
            $versionPattern = "1.2.3-ciJ-B"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.3-ci$julian-7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.2.3-ciJ-BB'" {
            $versionPattern = "1.2.3-ciJ-BB"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.3-ci$julian-07"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.2.3-ciJ-BBB'" {
            $versionPattern = "1.2.3-ciJ-BBB"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.3-ci$julian-007"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context "when file-version is provided with #-tokens and using .NET format" {
        $buildNumber = "Test_2014-11-27_2.3.1.7"
        $path = "TestDrive:\AssemblyInfo.cs"
        $version = "1.2.3.4"

        Set-Content -Path $path -Value $AssemblyInfo_CS

        It "should return correct version when format is '#.#.#.#'" {
            $versionPattern = "#.#.#.#"
            $expectedVersion = "1.2.3.4"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#.#.0'" {
            $versionPattern = "#.#.#.0"
            $expectedVersion = "1.2.3.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#.0.0'" {
            $versionPattern = "#.#.0.0"
            $expectedVersion = "1.2.0.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.0.0.0'" {
            $versionPattern = "#.0.0.0"
            $expectedVersion = "1.0.0.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#.#'" {
            $versionPattern = "#.#.#"
            $expectedVersion = "1.2.3"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#.0'" {
            $versionPattern = "#.#.0"
            $expectedVersion = "1.2.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.0.0'" {
            $versionPattern = "#.0.0"
            $expectedVersion = "1.0.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#'" {
            $versionPattern = "#.#"
            $expectedVersion = "1.2"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.0'" {
            $versionPattern = "#.0"
            $expectedVersion = "1.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context "when file-version is provided with #-tokens and using SemVer format" {
        $buildNumber = "Test_2014-11-27"
        $path = "TestDrive:\AssemblyInfo.cs"
        $version = "1.2.3-ci0008+14331.07"

        Set-Content -Path $path -Value $AssemblyInfo_CS

        It "should return correct version when format is '#.#.###'" {
            $versionPattern = "#.#.###"
            $expectedVersion = "1.2.3-ci0008+14331.07"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#.##'" {
            $versionPattern = "#.#.##"
            $expectedVersion = "1.2.3-ci0008"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#.#'" {
            $versionPattern = "#.#.#"
            $expectedVersion = "1.2.3"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#.0'" {
            $versionPattern = "#.#.0"
            $expectedVersion = "1.2.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.0.0'" {
            $versionPattern = "#.0.0"
            $expectedVersion = "1.0.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context "when file-version contains placeholders" {
        $buildNumber = "Test_2014-11-27"
        $path = "TestDrive:\AssemblyInfo.cs"
        $version = "4.3.2.1"

        Set-Content -Path $path -Value $AssemblyInfo_CS

        It "should return single placeholder as is" {
            $versionPattern = "#.#.{0}"
            $expectedVersion = "4.3.{0}"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return multiple placeholder as is" {
            $versionPattern = "#.{1}#.{0}"
            $expectedVersion = "4.{1}3.{0}"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context "when product-version is provided with formatting" {
        $buildNumber = "Test_2014-11-27_2.3.1.7"
        $path = "TestDrive:\AssemblyInfo.cs"

        Set-Content -Path $path -Value $AssemblyInfo_CS

        It "should return correct version when pattern is '1.2.J.B'" {
            $versionPattern = "1.2.J.B"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.$julian.7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is 'YYYY.M.D.B'" {
            $versionPattern = "YYYY.M.D.B"
            $now = [DateTime]::Now
            $expectedVersion = "$($now.Year).$($now.Month).$($now.Day).7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is 'YYYY.MM.DD.BB'" {
            $versionPattern = "YYYY.MM.DD.BB"
            $now = [DateTime]::Now
            $expectedVersion = "$($now.Year).$($now.Month).$($now.Day).7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is 'YYYY.MM.DD.BBB'" {
            $versionPattern = "YYYY.MM.DD.BBB"
            $now = [DateTime]::Now
            $expectedVersion = "$($now.Year).$($now.Month).$($now.Day).7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.YY.MMDD.B'" {
            $versionPattern = "1.YY.MMDD.B"
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month)$($now.Day.ToString("00")).7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.YY.MD.B'" {
            $buildNumber = "Test_2014-11-27_2.3.1.8"
            $versionPattern = "1.YY.MD.B"
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month)$($now.Day).8"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.YY.MM.DDBB'" {
            $versionPattern = "1.YY.MM.DDBB"
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month).$($now.Day)07"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.YY.MM.DDBBB'" {
            $versionPattern = "1.YY.MM.DDBBB"
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month).$($now.Day)007"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.2.3-ci+J.B'" {
            $versionPattern = "1.2.3-ci+J.B"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.3-ci+$julian.7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.2.3-ci+J.BB'" {
            $versionPattern = "1.2.3-ci+J.BB"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.3-ci+$julian.07"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.2.3-ci+J.BBB'" {
            $versionPattern = "1.2.3-ci+J.BBB"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.3-ci+$julian.007"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.2.3-ciJ-B'" {
            $versionPattern = "1.2.3-ciJ-B"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.3-ci$julian-7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.2.3-ciJ-BB'" {
            $versionPattern = "1.2.3-ciJ-BB"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.3-ci$julian-07"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.2.3-ciJ-BBB'" {
            $versionPattern = "1.2.3-ciJ-BBB"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.3-ci$julian-007"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context "when product-version is provided with #-tokens and using .NET format" {
        $buildNumber = "Test_2014-11-27_2.3.1.7"
        $path = "TestDrive:\AssemblyInfo.cs"
        $version = "1.2.3.4"

        Set-Content -Path $path -Value $AssemblyInfo_CS

        It "should return correct version when format is '#.#.#.#'" {
            $versionPattern = "#.#.#.#"
            $expectedVersion = "1.2.3.4"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#.#.0'" {
            $versionPattern = "#.#.#.0"
            $expectedVersion = "1.2.3.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#.0.0'" {
            $versionPattern = "#.#.0.0"
            $expectedVersion = "1.2.0.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.0.0.0'" {
            $versionPattern = "#.0.0.0"
            $expectedVersion = "1.0.0.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#.#'" {
            $versionPattern = "#.#.#"
            $expectedVersion = "1.2.3"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#.0'" {
            $versionPattern = "#.#.0"
            $expectedVersion = "1.2.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.0.0'" {
            $versionPattern = "#.0.0"
            $expectedVersion = "1.0.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#'" {
            $versionPattern = "#.#"
            $expectedVersion = "1.2"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.0'" {
            $versionPattern = "#.0"
            $expectedVersion = "1.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context "when product-version is provided with #-tokens and using SemVer format" {
        $buildNumber = "Test_2014-11-27"
        $path = "TestDrive:\AssemblyInfo.cs"
        $version = "1.2.3-ci0008+14331.07"

        Set-Content -Path $path -Value $AssemblyInfo_CS

        It "should return correct version when format is '#.#.###'" {
            $versionPattern = "#.#.###"
            $expectedVersion = "1.2.3-ci0008+14331.07"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#.##'" {
            $versionPattern = "#.#.##"
            $expectedVersion = "1.2.3-ci0008"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#.#'" {
            $versionPattern = "#.#.#"
            $expectedVersion = "1.2.3"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#.0'" {
            $versionPattern = "#.#.0"
            $expectedVersion = "1.2.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.0.0'" {
            $versionPattern = "#.0.0"
            $expectedVersion = "1.0.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context "when product-version contains placeholders" {
        $buildNumber = "Test_2014-11-27"
        $path = "TestDrive:\AssemblyInfo.cs"
        $version = "4.3.2.1"

        Set-Content -Path $path -Value $AssemblyInfo_CS

        It "should return single placeholder as is" {
            $versionPattern = "#.#.{0}"
            $expectedVersion = "4.3.{0}"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should return multiple placeholder as is" {
            $versionPattern = "#.{1}#.{0}"
            $expectedVersion = "4.{1}3.{0}"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context "when package-version is provided with formatting" {
        $buildNumber = "Test_2014-11-27_2.3.1.7"
        $path = "TestDrive:\package.nuspec"

        Set-Content -Path $path -Value $Package_Nuspec

        It "should return correct version when pattern is '1.2.J.B'" {
            $versionPattern = "1.2.J.B"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.$julian.7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is 'YYYY.M.D.B'" {
            $versionPattern = "YYYY.M.D.B"
            $now = [DateTime]::Now
            $expectedVersion = "$($now.Year).$($now.Month).$($now.Day).7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is 'YYYY.MM.DD.BB'" {
            $versionPattern = "YYYY.MM.DD.BB"
            $now = [DateTime]::Now
            $expectedVersion = "$($now.Year).$($now.Month).$($now.Day).7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is 'YYYY.MM.DD.BBB'" {
            $versionPattern = "YYYY.MM.DD.BBB"
            $now = [DateTime]::Now
            $expectedVersion = "$($now.Year).$($now.Month).$($now.Day).7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.YY.MMDD.B'" {
            $versionPattern = "1.YY.MMDD.B"
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month)$($now.Day.ToString("00")).7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.YY.MD.B'" {
            $buildNumber = "Test_2014-11-27_2.3.1.8"
            $versionPattern = "1.YY.MD.B"
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month)$($now.Day).8"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.YY.MM.DDBB'" {
            $versionPattern = "1.YY.MM.DDBB"
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month).$($now.Day)07"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.YY.MM.DDBBB'" {
            $versionPattern = "1.YY.MM.DDBBB"
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month).$($now.Day)007"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.2.3-ci+J.B'" {
            $versionPattern = "1.2.3-ci+J.B"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.3-ci+$julian.7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.2.3-ci+J.BB'" {
            $versionPattern = "1.2.3-ci+J.BB"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.3-ci+$julian.07"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.2.3-ci+J.BBB'" {
            $versionPattern = "1.2.3-ci+J.BBB"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.3-ci+$julian.007"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.2.3-ciJ-B'" {
            $versionPattern = "1.2.3-ciJ-B"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.3-ci$julian-7"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.2.3-ciJ-BB'" {
            $versionPattern = "1.2.3-ciJ-BB"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.3-ci$julian-07"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when pattern is '1.2.3-ciJ-BBB'" {
            $versionPattern = "1.2.3-ciJ-BBB"
            $now = [DateTime]::Now
            $julian = "$($now.ToString("yy"))$($now.DayOfYear)"
            $expectedVersion = "1.2.3-ci$julian-007"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context "when package-version is provided with #-tokens and using .NET format" {
        $buildNumber = "Test_2014-11-27_2.3.1.7"
        $path = "TestDrive:\package.nuspec"
        $version = "1.2.3.4"

        Set-Content -Path $path -Value $Package_Nuspec

        It "should return correct version when format is '#.#.#.#'" {
            $versionPattern = "#.#.#.#"
            $expectedVersion = "1.2.3.4"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#.#.0'" {
            $versionPattern = "#.#.#.0"
            $expectedVersion = "1.2.3.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#.0.0'" {
            $versionPattern = "#.#.0.0"
            $expectedVersion = "1.2.0.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.0.0.0'" {
            $versionPattern = "#.0.0.0"
            $expectedVersion = "1.0.0.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#.#'" {
            $versionPattern = "#.#.#"
            $expectedVersion = "1.2.3"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#.0'" {
            $versionPattern = "#.#.0"
            $expectedVersion = "1.2.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.0.0'" {
            $versionPattern = "#.0.0"
            $expectedVersion = "1.0.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#'" {
            $versionPattern = "#.#"
            $expectedVersion = "1.2"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.0'" {
            $versionPattern = "#.0"
            $expectedVersion = "1.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context "when package-version is provided with #-tokens and using SemVer format" {
        $buildNumber = "Test_2014-11-27"
        $path = "TestDrive:\package.nuspec"
        $version = "1.2.3-ci0008+14331.07"

        Set-Content -Path $path -Value $Package_Nuspec

        It "should return correct version when format is '#.#.###'" {
            $versionPattern = "#.#.###"
            # NuGet does not fully support SemVer, so '.' & '+' are replaced with '-'
            $expectedVersion = "1.2.3-ci0008-14331-07"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#.##'" {
            $versionPattern = "#.#.##"
            $expectedVersion = "1.2.3-ci0008"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#.#'" {
            $versionPattern = "#.#.#"
            $expectedVersion = "1.2.3"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.#.0'" {
            $versionPattern = "#.#.0"
            $expectedVersion = "1.2.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should return correct version when format is '#.0.0'" {
            $versionPattern = "#.0.0"
            $expectedVersion = "1.0.0"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context "when package-version contains placeholders" {
        $buildNumber = "Test_2014-11-27"
        $path = "TestDrive:\package.nuspec"
        $version = "4.3.2.1"

        Set-Content -Path $path -Value $Package_Nuspec

        It "should return single placeholder as is" {
            $versionPattern = "#.#.{0}"
            $expectedVersion = "4.3.{0}"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should return multiple placeholder as is" {
            $versionPattern = "#.{1}#.{0}"
            $expectedVersion = "4.{1}3.{0}"

            Update-Version -SourcesDirectory "TestDrive:\" -BuildNumber $buildNumber -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }
    }
}
