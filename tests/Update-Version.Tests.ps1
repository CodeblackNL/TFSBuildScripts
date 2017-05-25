##-----------------------------------------------------------------------
## <copyright file="Update-Version.Tests.ps1">(c) https://github.com/CodeblackNL/TFSBuildScripts. See https://github.com/CodeblackNL/TFSBuildScripts/blob/master/LICENSE. </copyright>
##-----------------------------------------------------------------------

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

Describe 'Update-Version' {
    $now = [DateTime]::Now
    $julian = "$($now.ToString("yy"))$($now.DayOfYear.ToString('000'))"

    Context 'when version is explicitly provided in .NET format' {
        $buildNumber = 'Test_2014-11-27'
        $path = 'TestDrive:\AssemblyInfo.cs'
        $nuspecPath = 'TestDrive:\package.nuspec'
        $expectedVersion = '2.3.1.4'

        Set-Content -Path $path -Value $AssemblyInfo_CS
        Set-Content -Path $nuspecPath -Value $Package_Nuspec

        $env:BUILD_SOURCESDIRECTORY = 'TestDrive:\'
        $env:BUILD_BUILDNUMBER = $buildNumber

        It 'should apply this version to the assembly-version' {
            ..\src\Update-Version.ps1 -Version $expectedVersion

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It 'should apply this version to the file-version' {
            ..\src\Update-Version.ps1 -Version $expectedVersion

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It 'should apply this version to the product-version' {
            ..\src\Update-Version.ps1 -Version $expectedVersion

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It 'should apply this version to the package-version' {
            ..\src\Update-Version.ps1 -Version $expectedVersion

            $actualVersion = Get-PackageVersion -Path $nuspecPath
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context 'when version is explicitly provided in SemVer format' {
        $buildNumber = 'Test_2014-11-27'
        $path = 'TestDrive:\AssemblyInfo.cs'
        $nuspecPath = 'TestDrive:\package.nuspec'
        $version = '2.3.1-ci42+12345.0'

        Set-Content -Path $path -Value $AssemblyInfo_CS
        Set-Content -Path $nuspecPath -Value $Package_Nuspec

        $env:BUILD_SOURCESDIRECTORY = 'TestDrive:\'
        $env:BUILD_BUILDNUMBER = $buildNumber

        It 'should apply this version to the assembly-version' {
            ..\src\Update-Version.ps1 -Version $version

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            # assembly-version does not support SemVer, so the #.#.#.0 pattern is used
            $actualVersion | Should Be '2.3.1.0'
        }

        It 'should apply this version to the file-version' {
            ..\src\Update-Version.ps1 -Version $version

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            # assembly-version does not support SemVer, so the #.#.#.0 pattern is used
            $actualVersion | Should Be '2.3.1.0'
        }

        It 'should apply this version to the product-version' {
            ..\src\Update-Version.ps1 -Version $version

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be '2.3.1-ci42+12345.0'
        }

        It 'should apply this version to the package-version' {
            ..\src\Update-Version.ps1 -Version $version

            $actualVersion = Get-PackageVersion -Path $nuspecPath
            # NuGet does not fully support SemVer, so '.' & '+' are replaced with '-'
            $actualVersion | Should Be '2.3.1-ci42-12345-0'
        }
    }

    Context 'when version is explicitely provided in .NET format with formatting' {
        # NOTE: since only the product-version allows all versioning-patterns,
        #       the version-patterns in this context are only tested against the product-version;
        #       it is assumed (for now) that these patterns will work for the other versions as well
        $buildNumber = 'Test_2014-11-27_2.3.1.7'
        $path = 'TestDrive:\AssemblyInfo.cs'

        Set-Content -Path $path -Value $AssemblyInfo_CS

        $env:BUILD_SOURCESDIRECTORY = 'TestDrive:\'
        $env:BUILD_BUILDNUMBER = $buildNumber

        It "should apply the correct version when pattern is '1.2.J.B'" {
            $versionPattern = '1.2.J.B'
            $expectedVersion = "1.2.$julian.7"

            ..\src\Update-Version.ps1 -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is 'YYYY.M.D.B'" {
            $versionPattern = 'YYYY.M.D.B'
            $now = [DateTime]::Now
            $expectedVersion = "$($now.Year).$($now.Month).$($now.Day).7"

            ..\src\Update-Version.ps1 -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is 'YYYY.MM.DD.BB'" {
            $versionPattern = 'YYYY.MM.DD.BB'
            $now = [DateTime]::Now
            $expectedVersion = "$($now.Year).$($now.Month).$($now.Day).7"

            ..\src\Update-Version.ps1 -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is 'YYYY.MM.DD.BBB'" {
            $versionPattern = 'YYYY.MM.DD.BBB'
            $now = [DateTime]::Now
            $expectedVersion = "$($now.Year).$($now.Month).$($now.Day).7"

            ..\src\Update-Version.ps1 -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.YY.MMDD.B'" {
            $versionPattern = '1.YY.MMDD.B'
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month)$($now.Day.ToString("00")).7"

            ..\src\Update-Version.ps1 -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.YY.MD.B'" {
            $versionPattern = '1.YY.MD.B'
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month)$($now.Day).7"

            ..\src\Update-Version.ps1 -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.YY.MM.DDBB'" {
            $versionPattern = '1.YY.MM.DDBB'
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month).$($now.Day)07"

            ..\src\Update-Version.ps1 -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.YY.MM.DDBBB'" {
            $versionPattern = '1.YY.MM.DDBBB'
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month).$($now.Day)007"

            ..\src\Update-Version.ps1 -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '#.#.#.#'" {
            $versionPattern = '#.#.#.#'
            $expectedVersion = '2.3.1.7'

            ..\src\Update-Version.ps1 -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '#.#.#.0'" {
            $versionPattern = '#.#.#.0'
            $expectedVersion = '2.3.1.0'

            ..\src\Update-Version.ps1 -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '#.#.0.0'" {
            $versionPattern = '#.#.0.0'
            $expectedVersion = '2.3.0.0'

            ..\src\Update-Version.ps1 -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '#.0.0.0'" {
            $versionPattern = '#.0.0.0'
            $expectedVersion = '2.0.0.0'

            ..\src\Update-Version.ps1 -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '#.#.#.B'" {
            $versionPattern = '#.#.#.B'
            $expectedVersion = '2.3.1.7'

            ..\src\Update-Version.ps1 -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '#.#.#.100B'" {
            $versionPattern = '#.#.#.100B'
            $expectedVersion = '2.3.1.1007'

            ..\src\Update-Version.ps1 -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '#.#.#.10BB'" {
            $versionPattern = '#.#.#.10BB'
            $expectedVersion = '2.3.1.1007'

            ..\src\Update-Version.ps1 -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '#.#.#.1BBB'" {
            $versionPattern = '#.#.#.1BBB'
            $expectedVersion = '2.3.1.1007'

            ..\src\Update-Version.ps1 -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context 'when version is explicitely provided in SemVer format with formatting' {
        # NOTE: since only the product-version allows all versioning-patterns,
        #       the version-patterns in this context are only tested against the product-version;
        #       it is assumed (for now) that these patterns will work for the other versions as well
        $buildNumber = 'Test_2014-11-27_2.3.1.7'
        $path = 'TestDrive:\AssemblyInfo.cs'

        Set-Content -Path $path -Value $AssemblyInfo_CS

        $env:BUILD_SOURCESDIRECTORY = 'TestDrive:\'
        $env:BUILD_BUILDNUMBER = $buildNumber

        It "should apply the correct version when pattern is '1.2.3-ci+J.B'" {
            $versionPattern = '1.2.3-ci+J.B'
            $expectedVersion = "1.2.3-ci+$julian.7"

            ..\src\Update-Version.ps1 -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.2.3-ci+J.BB'" {
            $versionPattern = '1.2.3-ci+J.BB'
            $expectedVersion = "1.2.3-ci+$julian.07"

            ..\src\Update-Version.ps1 -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.2.3-ci+J.BBB'" {
            $versionPattern = '1.2.3-ci+J.BBB'
            $expectedVersion = "1.2.3-ci+$julian.007"

            ..\src\Update-Version.ps1 -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.2.3-ciJ-B'" {
            $versionPattern = '1.2.3-ciJ-B'
            $expectedVersion = "1.2.3-ci$julian-7"

            ..\src\Update-Version.ps1 -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.2.3-ciJ-BB'" {
            $versionPattern = '1.2.3-ciJ-BB'
            $expectedVersion = "1.2.3-ci$julian-07"

            ..\src\Update-Version.ps1 -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.2.3-ciJ-BBB'" {
            $versionPattern = '1.2.3-ciJ-BBB'
            $expectedVersion = "1.2.3-ci$julian-007"

            ..\src\Update-Version.ps1 -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '#.#.#-ciB'" {
            $versionPattern = '#.#.#-ciB'
            $expectedVersion = "2.3.1-ci7"

            ..\src\Update-Version.ps1 -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '#.#.#-ciBB'" {
            $versionPattern = '#.#.#-ciBB'
            $expectedVersion = "2.3.1-ci07"

            ..\src\Update-Version.ps1 -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '#.#.#-ciBBB'" {
            $versionPattern = '#.#.#-ciBBB'
            $expectedVersion = "2.3.1-ci007"

            ..\src\Update-Version.ps1 -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '#.#.#-ciJ.B'" {
            $versionPattern = '#.#.#-ci+J.B'
            $expectedVersion = "2.3.1-ci+$julian.7"

            ..\src\Update-Version.ps1 -Version $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context 'when version is in the build-number in .NET format' {
        $buildNumber = 'Test_2014-11-27_3.2.12345.7'
        $path = 'TestDrive:\AssemblyInfo.cs'
        $nuspecPath = 'TestDrive:\package.nuspec'
        $expectedVersion = '3.2.12345.7'

        Set-Content -Path $path -Value $AssemblyInfo_CS
        Set-Content -Path $nuspecPath -Value $Package_Nuspec

        $env:BUILD_SOURCESDIRECTORY = 'TestDrive:\'
        $env:BUILD_BUILDNUMBER = $buildNumber

        It 'should apply this version to the assembly-version' {
            ..\src\Update-Version.ps1

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It 'should apply this version to the file-version' {
            ..\src\Update-Version.ps1

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It 'should apply this version to the product-version' {
            ..\src\Update-Version.ps1

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It 'should apply this version to the package-version' {
            ..\src\Update-Version.ps1

            $actualVersion = Get-PackageVersion -Path $nuspecPath
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context 'when version is in the build-number in SemVer format' {
        $buildNumber = 'Test_2014-11-27_2.3.1-ci42+12345.07'
        $path = 'TestDrive:\AssemblyInfo.cs'
        $nuspecPath = 'TestDrive:\package.nuspec'

        Set-Content -Path $path -Value $AssemblyInfo_CS
        Set-Content -Path $nuspecPath -Value $Package_Nuspec

        $env:BUILD_SOURCESDIRECTORY = 'TestDrive:\'
        $env:BUILD_BUILDNUMBER = $buildNumber

        It 'should apply this version to the assembly-version' {
            ..\src\Update-Version.ps1

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            # assembly-version does not support SemVer, so the #.#.#.0 pattern is used
            $actualVersion | Should Be '2.3.1.0'
        }

        It 'should apply this version to the file-version' {
            ..\src\Update-Version.ps1

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            # assembly-version does not support SemVer, so the #.#.#.0 pattern is used
            $actualVersion | Should Be '2.3.1.0'
        }

        It 'should apply this version to the product-version' {
            ..\src\Update-Version.ps1

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be '2.3.1-ci42+12345.07'
        }

        It 'should apply this version to the package-version' {
            ..\src\Update-Version.ps1

            $actualVersion = Get-PackageVersion -Path $nuspecPath
            # NuGet does not fully support SemVer, so '.' & '+' are replaced with '-'
            $actualVersion | Should Be '2.3.1-ci42-12345-07'
        }
    }

    Context 'when assembly-version is provided with formatting' {
        $buildNumber = 'Test_2014-11-27_2.3.1.7'
        $path = 'TestDrive:\AssemblyInfo.cs'

        Set-Content -Path $path -Value $AssemblyInfo_CS

        $env:BUILD_SOURCESDIRECTORY = 'TestDrive:\'
        $env:BUILD_BUILDNUMBER = $buildNumber

        It "should apply the correct version when pattern is '1.2.J.B'" {
            $versionPattern = '1.2.J.B'
            $expectedVersion = "1.2.$julian.7"

            ..\src\Update-Version.ps1 -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is 'YYYY.M.D.B'" {
            $versionPattern = 'YYYY.M.D.B'
            $now = [DateTime]::Now
            $expectedVersion = "$($now.Year).$($now.Month).$($now.Day).7"

            ..\src\Update-Version.ps1 -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is 'YYYY.MM.DD.BB'" {
            $versionPattern = 'YYYY.MM.DD.BB'
            $now = [DateTime]::Now
            $expectedVersion = "$($now.Year).$($now.Month).$($now.Day).7"

            ..\src\Update-Version.ps1 -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is 'YYYY.MM.DD.BBB'" {
            $versionPattern = 'YYYY.MM.DD.BBB'
            $now = [DateTime]::Now
            $expectedVersion = "$($now.Year).$($now.Month).$($now.Day).7"

            ..\src\Update-Version.ps1 -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.YY.MMDD.B'" {
            $versionPattern = '1.YY.MMDD.B'
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month)$($now.Day.ToString("00")).7"

            ..\src\Update-Version.ps1 -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.YY.MD.B'" {
            $versionPattern = '1.YY.MD.B'
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month)$($now.Day).7"

            ..\src\Update-Version.ps1 -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.YY.MM.DDBB'" {
            $versionPattern = '1.YY.MM.DDBB'
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month).$($now.Day)07"

            ..\src\Update-Version.ps1 -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.YY.MM.DDBBB'" {
            $versionPattern = '1.YY.MM.DDBBB'
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month).$($now.Day)007"

            ..\src\Update-Version.ps1 -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.2.3-ci+J.B'" {
            $versionPattern = '1.2.3-ci+J.B'
            $expectedVersion = "1.2.3-ci+$julian.7"

            ..\src\Update-Version.ps1 -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.2.3-ci+J.BB'" {
            $versionPattern = '1.2.3-ci+J.BB'
            $expectedVersion = "1.2.3-ci+$julian.07"

            ..\src\Update-Version.ps1 -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.2.3-ci+J.BBB'" {
            $versionPattern = '1.2.3-ci+J.BBB'
            $expectedVersion = "1.2.3-ci+$julian.007"

            ..\src\Update-Version.ps1 -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.2.3-ciJ-B'" {
            $versionPattern = '1.2.3-ciJ-B'
            $expectedVersion = "1.2.3-ci$julian-7"

            ..\src\Update-Version.ps1 -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.2.3-ciJ-BB'" {
            $versionPattern = '1.2.3-ciJ-BB'
            $expectedVersion = "1.2.3-ci$julian-07"

            ..\src\Update-Version.ps1 -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.2.3-ciJ-BBB'" {
            $versionPattern = '1.2.3-ciJ-BBB'
            $expectedVersion = "1.2.3-ci$julian-007"

            ..\src\Update-Version.ps1 -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context 'when assembly-version is provided with #-tokens and using .NET format' {
        $buildNumber = 'Test_2014-11-27_2.3.1.7'
        $path = 'TestDrive:\AssemblyInfo.cs'
        $version = '1.2.3.4'

        Set-Content -Path $path -Value $AssemblyInfo_CS

        $env:BUILD_SOURCESDIRECTORY = 'TestDrive:\'
        $env:BUILD_BUILDNUMBER = $buildNumber

        It "should apply the correct version when format is '#.#.#.#'" {
            $versionPattern = '#.#.#.#'
            $expectedVersion = '1.2.3.4'

            ..\src\Update-Version.ps1 -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#.#.0'" {
            $versionPattern = '#.#.#.0'
            $expectedVersion = '1.2.3.0'

            ..\src\Update-Version.ps1 -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#.0.0'" {
            $versionPattern = '#.#.0.0'
            $expectedVersion = '1.2.0.0'

            ..\src\Update-Version.ps1 -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.0.0.0'" {
            $versionPattern = '#.0.0.0'
            $expectedVersion = '1.0.0.0'

            ..\src\Update-Version.ps1 -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#.#'" {
            $versionPattern = '#.#.#'
            $expectedVersion = '1.2.3'

            ..\src\Update-Version.ps1 -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#.0'" {
            $versionPattern = '#.#.0'
            $expectedVersion = '1.2.0'

            ..\src\Update-Version.ps1 -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.0.0'" {
            $versionPattern = '#.0.0'
            $expectedVersion = '1.0.0'

            ..\src\Update-Version.ps1 -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#'" {
            $versionPattern = '#.#'
            $expectedVersion = '1.2'

            ..\src\Update-Version.ps1 -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.0'" {
            $versionPattern = '#.0'
            $expectedVersion = '1.0'

            ..\src\Update-Version.ps1 -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context 'when assembly-version is provided with #-tokens and using SemVer format' {
        $buildNumber = 'Test_2014-11-27'
        $path = 'TestDrive:\AssemblyInfo.cs'
        $version = '1.2.3-ci0008+14331.07'

        Set-Content -Path $path -Value $AssemblyInfo_CS

        $env:BUILD_SOURCESDIRECTORY = 'TestDrive:\'
        $env:BUILD_BUILDNUMBER = $buildNumber

        It "should apply the correct version when format is '#.#.###'" {
            $versionPattern = '#.#.###'
            $expectedVersion = '1.2.3-ci0008+14331.07'

            ..\src\Update-Version.ps1 -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#.##'" {
            $versionPattern = '#.#.##'
            $expectedVersion = '1.2.3-ci0008'

            ..\src\Update-Version.ps1 -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#.#'" {
            $versionPattern = '#.#.#'
            $expectedVersion = '1.2.3'

            ..\src\Update-Version.ps1 -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#.0'" {
            $versionPattern = '#.#.0'
            $expectedVersion = '1.2.0'

            ..\src\Update-Version.ps1 -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.0.0'" {
            $versionPattern = '#.0.0'
            $expectedVersion = '1.0.0'

            ..\src\Update-Version.ps1 -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context 'when assembly-version contains placeholders' {
        $buildNumber = 'Test_2014-11-27'
        $path = 'TestDrive:\AssemblyInfo.cs'
        $version = '4.3.2.1'

        Set-Content -Path $path -Value $AssemblyInfo_CS

        $env:BUILD_SOURCESDIRECTORY = 'TestDrive:\'
        $env:BUILD_BUILDNUMBER = $buildNumber

        It 'should leave a single placeholder as is' {
            $versionPattern = '#.#.{0}'
            $expectedVersion = '4.3.{0}'

            ..\src\Update-Version.ps1 -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }

        It 'should leave multiple placeholders as is' {
            $versionPattern = '#.{1}#.{0}'
            $expectedVersion = '4.{1}3.{0}'

            ..\src\Update-Version.ps1 -Version $version -AssemblyVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType AssemblyVersion
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context 'when file-version is provided with formatting' {
        $buildNumber = 'Test_2014-11-27_2.3.1.7'
        $path = 'TestDrive:\AssemblyInfo.cs'

        Set-Content -Path $path -Value $AssemblyInfo_CS

        $env:BUILD_SOURCESDIRECTORY = 'TestDrive:\'
        $env:BUILD_BUILDNUMBER = $buildNumber

        It "should apply the correct version when pattern is '1.2.J.B'" {
            $versionPattern = '1.2.J.B'
            $expectedVersion = "1.2.$julian.7"

            ..\src\Update-Version.ps1 -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is 'YYYY.M.D.B'" {
            $versionPattern = 'YYYY.M.D.B'
            $now = [DateTime]::Now
            $expectedVersion = "$($now.Year).$($now.Month).$($now.Day).7"

            ..\src\Update-Version.ps1 -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is 'YYYY.MM.DD.BB'" {
            $versionPattern = 'YYYY.MM.DD.BB'
            $now = [DateTime]::Now
            $expectedVersion = "$($now.Year).$($now.Month).$($now.Day).7"

            ..\src\Update-Version.ps1 -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is 'YYYY.MM.DD.BBB'" {
            $versionPattern = 'YYYY.MM.DD.BBB'
            $now = [DateTime]::Now
            $expectedVersion = "$($now.Year).$($now.Month).$($now.Day).7"

            ..\src\Update-Version.ps1 -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.YY.MMDD.B'" {
            $versionPattern = '1.YY.MMDD.B'
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month)$($now.Day.ToString("00")).7"

            ..\src\Update-Version.ps1 -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.YY.MD.B'" {
            $versionPattern = '1.YY.MD.B'
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month)$($now.Day).7"

            ..\src\Update-Version.ps1 -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.YY.MM.DDBB'" {
            $versionPattern = '1.YY.MM.DDBB'
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month).$($now.Day)07"

            ..\src\Update-Version.ps1 -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.YY.MM.DDBBB'" {
            $versionPattern = '1.YY.MM.DDBBB'
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month).$($now.Day)007"

            ..\src\Update-Version.ps1 -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.2.3-ci+J.B'" {
            $versionPattern = '1.2.3-ci+J.B'
            $expectedVersion = "1.2.3-ci+$julian.7"

            ..\src\Update-Version.ps1 -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.2.3-ci+J.BB'" {
            $versionPattern = '1.2.3-ci+J.BB'
            $expectedVersion = "1.2.3-ci+$julian.07"

            ..\src\Update-Version.ps1 -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.2.3-ci+J.BBB'" {
            $versionPattern = '1.2.3-ci+J.BBB'
            $expectedVersion = "1.2.3-ci+$julian.007"

            ..\src\Update-Version.ps1 -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.2.3-ciJ-B'" {
            $versionPattern = '1.2.3-ciJ-B'
            $expectedVersion = "1.2.3-ci$julian-7"

            ..\src\Update-Version.ps1 -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.2.3-ciJ-BB'" {
            $versionPattern = '1.2.3-ciJ-BB'
            $expectedVersion = "1.2.3-ci$julian-07"

            ..\src\Update-Version.ps1 -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.2.3-ciJ-BBB'" {
            $versionPattern = '1.2.3-ciJ-BBB'
            $expectedVersion = "1.2.3-ci$julian-007"

            ..\src\Update-Version.ps1 -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context 'when file-version is provided with #-tokens and using .NET format' {
        $buildNumber = 'Test_2014-11-27_2.3.1.7'
        $path = 'TestDrive:\AssemblyInfo.cs'
        $version = '1.2.3.4'

        Set-Content -Path $path -Value $AssemblyInfo_CS

        $env:BUILD_SOURCESDIRECTORY = 'TestDrive:\'
        $env:BUILD_BUILDNUMBER = $buildNumber

        It "should apply the correct version when format is '#.#.#.#'" {
            $versionPattern = '#.#.#.#'
            $expectedVersion = '1.2.3.4'

            ..\src\Update-Version.ps1 -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#.#.0'" {
            $versionPattern = '#.#.#.0'
            $expectedVersion = '1.2.3.0'

            ..\src\Update-Version.ps1 -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#.0.0'" {
            $versionPattern = '#.#.0.0'
            $expectedVersion = '1.2.0.0'

            ..\src\Update-Version.ps1 -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.0.0.0'" {
            $versionPattern = '#.0.0.0'
            $expectedVersion = '1.0.0.0'

            ..\src\Update-Version.ps1 -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#.#'" {
            $versionPattern = '#.#.#'
            $expectedVersion = '1.2.3'

            ..\src\Update-Version.ps1 -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#.0'" {
            $versionPattern = '#.#.0'
            $expectedVersion = '1.2.0'

            ..\src\Update-Version.ps1 -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.0.0'" {
            $versionPattern = '#.0.0'
            $expectedVersion = '1.0.0'

            ..\src\Update-Version.ps1 -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#'" {
            $versionPattern = '#.#'
            $expectedVersion = '1.2'

            ..\src\Update-Version.ps1 -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.0'" {
            $versionPattern = '#.0'
            $expectedVersion = '1.0'

            ..\src\Update-Version.ps1 -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context 'when file-version is provided with #-tokens and using SemVer format' {
        $buildNumber = 'Test_2014-11-27'
        $path = 'TestDrive:\AssemblyInfo.cs'
        $version = '1.2.3-ci0008+14331.07'

        Set-Content -Path $path -Value $AssemblyInfo_CS

        $env:BUILD_SOURCESDIRECTORY = 'TestDrive:\'
        $env:BUILD_BUILDNUMBER = $buildNumber

        It "should apply the correct version when format is '#.#.###'" {
            $versionPattern = '#.#.###'
            $expectedVersion = '1.2.3-ci0008+14331.07'

            ..\src\Update-Version.ps1 -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#.##'" {
            $versionPattern = '#.#.##'
            $expectedVersion = '1.2.3-ci0008'

            ..\src\Update-Version.ps1 -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#.#'" {
            $versionPattern = '#.#.#'
            $expectedVersion = '1.2.3'

            ..\src\Update-Version.ps1 -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#.0'" {
            $versionPattern = '#.#.0'
            $expectedVersion = '1.2.0'

            ..\src\Update-Version.ps1 -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.0.0'" {
            $versionPattern = '#.0.0'
            $expectedVersion = '1.0.0'

            ..\src\Update-Version.ps1 -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context 'when file-version contains placeholders' {
        $buildNumber = 'Test_2014-11-27'
        $path = 'TestDrive:\AssemblyInfo.cs'
        $version = '4.3.2.1'

        Set-Content -Path $path -Value $AssemblyInfo_CS

        $env:BUILD_SOURCESDIRECTORY = 'TestDrive:\'
        $env:BUILD_BUILDNUMBER = $buildNumber

        It 'should leave a single placeholder as is' {
            $versionPattern = '#.#.{0}'
            $expectedVersion = '4.3.{0}'

            ..\src\Update-Version.ps1 -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }

        It 'should leave multiple placeholders as is' {
            $versionPattern = '#.{1}#.{0}'
            $expectedVersion = '4.{1}3.{0}'

            ..\src\Update-Version.ps1 -Version $version -FileVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType FileVersion
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context 'when product-version is provided with formatting' {
        $buildNumber = 'Test_2014-11-27_2.3.1.7'
        $path = 'TestDrive:\AssemblyInfo.cs'

        Set-Content -Path $path -Value $AssemblyInfo_CS

        $env:BUILD_SOURCESDIRECTORY = 'TestDrive:\'
        $env:BUILD_BUILDNUMBER = $buildNumber

        It "should apply the correct version when pattern is '1.2.J.B'" {
            $versionPattern = '1.2.J.B'
            $expectedVersion = "1.2.$julian.7"

            ..\src\Update-Version.ps1 -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is 'YYYY.M.D.B'" {
            $versionPattern = 'YYYY.M.D.B'
            $now = [DateTime]::Now
            $expectedVersion = "$($now.Year).$($now.Month).$($now.Day).7"

            ..\src\Update-Version.ps1 -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is 'YYYY.MM.DD.BB'" {
            $versionPattern = 'YYYY.MM.DD.BB'
            $now = [DateTime]::Now
            $expectedVersion = "$($now.Year).$($now.Month).$($now.Day).7"

            ..\src\Update-Version.ps1 -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is 'YYYY.MM.DD.BBB'" {
            $versionPattern = 'YYYY.MM.DD.BBB'
            $now = [DateTime]::Now
            $expectedVersion = "$($now.Year).$($now.Month).$($now.Day).7"

            ..\src\Update-Version.ps1 -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.YY.MMDD.B'" {
            $versionPattern = '1.YY.MMDD.B'
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month)$($now.Day.ToString("00")).7"

            ..\src\Update-Version.ps1 -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.YY.MD.B'" {
            $versionPattern = '1.YY.MD.B'
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month)$($now.Day).7"

            ..\src\Update-Version.ps1 -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.YY.MM.DDBB'" {
            $versionPattern = '1.YY.MM.DDBB'
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month).$($now.Day)07"

            ..\src\Update-Version.ps1 -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.YY.MM.DDBBB'" {
            $versionPattern = '1.YY.MM.DDBBB'
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month).$($now.Day)007"

            ..\src\Update-Version.ps1 -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.2.3-ci+J.B'" {
            $versionPattern = '1.2.3-ci+J.B'
            $expectedVersion = "1.2.3-ci+$julian.7"

            ..\src\Update-Version.ps1 -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.2.3-ci+J.BB'" {
            $versionPattern = '1.2.3-ci+J.BB'
            $expectedVersion = "1.2.3-ci+$julian.07"

            ..\src\Update-Version.ps1 -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.2.3-ci+J.BBB'" {
            $versionPattern = '1.2.3-ci+J.BBB'
            $expectedVersion = "1.2.3-ci+$julian.007"

            ..\src\Update-Version.ps1 -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.2.3-ciJ-B'" {
            $versionPattern = '1.2.3-ciJ-B'
            $expectedVersion = "1.2.3-ci$julian-7"

            ..\src\Update-Version.ps1 -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.2.3-ciJ-BB'" {
            $versionPattern = '1.2.3-ciJ-BB'
            $expectedVersion = "1.2.3-ci$julian-07"

            ..\src\Update-Version.ps1 -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.2.3-ciJ-BBB'" {
            $versionPattern = '1.2.3-ciJ-BBB'
            $expectedVersion = "1.2.3-ci$julian-007"

            ..\src\Update-Version.ps1 -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context 'when product-version is provided with #-tokens and using .NET format' {
        $buildNumber = 'Test_2014-11-27_2.3.1.7'
        $path = 'TestDrive:\AssemblyInfo.cs'
        $version = '1.2.3.4'

        Set-Content -Path $path -Value $AssemblyInfo_CS

        $env:BUILD_SOURCESDIRECTORY = 'TestDrive:\'
        $env:BUILD_BUILDNUMBER = $buildNumber

        It "should apply the correct version when format is '#.#.#.#'" {
            $versionPattern = '#.#.#.#'
            $expectedVersion = '1.2.3.4'

            ..\src\Update-Version.ps1 -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#.#.0'" {
            $versionPattern = '#.#.#.0'
            $expectedVersion = '1.2.3.0'

            ..\src\Update-Version.ps1 -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#.0.0'" {
            $versionPattern = '#.#.0.0'
            $expectedVersion = '1.2.0.0'

            ..\src\Update-Version.ps1 -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.0.0.0'" {
            $versionPattern = '#.0.0.0'
            $expectedVersion = '1.0.0.0'

            ..\src\Update-Version.ps1 -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#.#'" {
            $versionPattern = '#.#.#'
            $expectedVersion = '1.2.3'

            ..\src\Update-Version.ps1 -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#.0'" {
            $versionPattern = '#.#.0'
            $expectedVersion = '1.2.0'

            ..\src\Update-Version.ps1 -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.0.0'" {
            $versionPattern = '#.0.0'
            $expectedVersion = '1.0.0'

            ..\src\Update-Version.ps1 -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#'" {
            $versionPattern = '#.#'
            $expectedVersion = '1.2'

            ..\src\Update-Version.ps1 -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.0'" {
            $versionPattern = '#.0'
            $expectedVersion = '1.0'

            ..\src\Update-Version.ps1 -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context 'when product-version is provided with #-tokens and using SemVer format' {
        $buildNumber = 'Test_2014-11-27'
        $path = 'TestDrive:\AssemblyInfo.cs'
        $version = '1.2.3-ci0008+14331.07'

        Set-Content -Path $path -Value $AssemblyInfo_CS

        $env:BUILD_SOURCESDIRECTORY = 'TestDrive:\'
        $env:BUILD_BUILDNUMBER = $buildNumber

        It "should apply the correct version when format is '#.#.###'" {
            $versionPattern = '#.#.###'
            $expectedVersion = '1.2.3-ci0008+14331.07'

            ..\src\Update-Version.ps1 -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#.##'" {
            $versionPattern = '#.#.##'
            $expectedVersion = '1.2.3-ci0008'

            ..\src\Update-Version.ps1 -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#.#'" {
            $versionPattern = '#.#.#'
            $expectedVersion = '1.2.3'

            ..\src\Update-Version.ps1 -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#.0'" {
            $versionPattern = '#.#.0'
            $expectedVersion = '1.2.0'

            ..\src\Update-Version.ps1 -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.0.0'" {
            $versionPattern = '#.0.0'
            $expectedVersion = '1.0.0'

            ..\src\Update-Version.ps1 -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context 'when product-version contains placeholders' {
        $buildNumber = 'Test_2014-11-27'
        $path = 'TestDrive:\AssemblyInfo.cs'
        $version = '4.3.2.1'

        Set-Content -Path $path -Value $AssemblyInfo_CS

        $env:BUILD_SOURCESDIRECTORY = 'TestDrive:\'
        $env:BUILD_BUILDNUMBER = $buildNumber

        It 'should leave a single placeholder as is' {
            $versionPattern = '#.#.{0}'
            $expectedVersion = '4.3.{0}'

            ..\src\Update-Version.ps1 -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }

        It 'should leave multiple placeholders as is' {
            $versionPattern = '#.{1}#.{0}'
            $expectedVersion = '4.{1}3.{0}'

            ..\src\Update-Version.ps1 -Version $version -ProductVersionPattern $versionPattern

            $actualVersion = Get-Version -Path $path -VersionType ProductVersion
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context 'when package-version is provided with formatting' {
        $buildNumber = 'Test_2014-11-27_2.3.1.7'
        $path = 'TestDrive:\package.nuspec'

        Set-Content -Path $path -Value $Package_Nuspec

        $env:BUILD_SOURCESDIRECTORY = 'TestDrive:\'
        $env:BUILD_BUILDNUMBER = $buildNumber

        It "should apply the correct version when pattern is '1.2.J.B'" {
            $versionPattern = '1.2.J.B'
            $expectedVersion = "1.2.$julian.7"

            ..\src\Update-Version.ps1 -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is 'YYYY.M.D.B'" {
            $versionPattern = 'YYYY.M.D.B'
            $now = [DateTime]::Now
            $expectedVersion = "$($now.Year).$($now.Month).$($now.Day).7"

            ..\src\Update-Version.ps1 -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is 'YYYY.MM.DD.BB'" {
            $versionPattern = 'YYYY.MM.DD.BB'
            $now = [DateTime]::Now
            $expectedVersion = "$($now.Year).$($now.Month).$($now.Day).7"

            ..\src\Update-Version.ps1 -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is 'YYYY.MM.DD.BBB'" {
            $versionPattern = 'YYYY.MM.DD.BBB'
            $now = [DateTime]::Now
            $expectedVersion = "$($now.Year).$($now.Month).$($now.Day).7"

            ..\src\Update-Version.ps1 -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.YY.MMDD.B'" {
            $versionPattern = '1.YY.MMDD.B'
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month)$($now.Day.ToString("00")).7"

            ..\src\Update-Version.ps1 -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.YY.MD.B'" {
            $versionPattern = '1.YY.MD.B'
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month)$($now.Day).7"

            ..\src\Update-Version.ps1 -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.YY.MM.DDBB'" {
            $versionPattern = '1.YY.MM.DDBB'
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month).$($now.Day)07"

            ..\src\Update-Version.ps1 -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.YY.MM.DDBBB'" {
            $versionPattern = '1.YY.MM.DDBBB'
            $now = [DateTime]::Now
            $expectedVersion = "1.$($now.ToString('yy')).$($now.Month).$($now.Day)007"

            ..\src\Update-Version.ps1 -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.2.3-ci+J.B'" {
            $versionPattern = '1.2.3-ci+J.B'
            $expectedVersion = "1.2.3-ci+$julian.7"

            ..\src\Update-Version.ps1 -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.2.3-ci+J.BB'" {
            $versionPattern = '1.2.3-ci+J.BB'
            $expectedVersion = "1.2.3-ci+$julian.07"

            ..\src\Update-Version.ps1 -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.2.3-ci+J.BBB'" {
            $versionPattern = '1.2.3-ci+J.BBB'
            $expectedVersion = "1.2.3-ci+$julian.007"

            ..\src\Update-Version.ps1 -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.2.3-ciJ-B'" {
            $versionPattern = '1.2.3-ciJ-B'
            $expectedVersion = "1.2.3-ci$julian-7"

            ..\src\Update-Version.ps1 -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.2.3-ciJ-BB'" {
            $versionPattern = '1.2.3-ciJ-BB'
            $expectedVersion = "1.2.3-ci$julian-07"

            ..\src\Update-Version.ps1 -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when pattern is '1.2.3-ciJ-BBB'" {
            $versionPattern = '1.2.3-ciJ-BBB'
            $expectedVersion = "1.2.3-ci$julian-007"

            ..\src\Update-Version.ps1 -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context 'when package-version is provided with #-tokens and using .NET format' {
        $buildNumber = 'Test_2014-11-27_2.3.1.7'
        $path = 'TestDrive:\package.nuspec'
        $version = '1.2.3.4'

        Set-Content -Path $path -Value $Package_Nuspec

        $env:BUILD_SOURCESDIRECTORY = 'TestDrive:\'
        $env:BUILD_BUILDNUMBER = $buildNumber

        It "should apply the correct version when format is '#.#.#.#'" {
            $versionPattern = '#.#.#.#'
            $expectedVersion = '1.2.3.4'

            ..\src\Update-Version.ps1 -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#.#.0'" {
            $versionPattern = '#.#.#.0'
            $expectedVersion = '1.2.3.0'

            ..\src\Update-Version.ps1 -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#.0.0'" {
            $versionPattern = '#.#.0.0'
            $expectedVersion = '1.2.0.0'

            ..\src\Update-Version.ps1 -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.0.0.0'" {
            $versionPattern = '#.0.0.0'
            $expectedVersion = '1.0.0.0'

            ..\src\Update-Version.ps1 -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#.#'" {
            $versionPattern = '#.#.#'
            $expectedVersion = '1.2.3'

            ..\src\Update-Version.ps1 -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#.0'" {
            $versionPattern = '#.#.0'
            $expectedVersion = '1.2.0'

            ..\src\Update-Version.ps1 -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.0.0'" {
            $versionPattern = '#.0.0'
            $expectedVersion = '1.0.0'

            ..\src\Update-Version.ps1 -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#'" {
            $versionPattern = '#.#'
            $expectedVersion = '1.2'

            ..\src\Update-Version.ps1 -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.0'" {
            $versionPattern = '#.0'
            $expectedVersion = '1.0'

            ..\src\Update-Version.ps1 -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context 'when package-version is provided with #-tokens and using SemVer format' {
        $buildNumber = 'Test_2014-11-27'
        $path = 'TestDrive:\package.nuspec'
        $version = '1.2.3-ci0008+14331.07'

        Set-Content -Path $path -Value $Package_Nuspec

        $env:BUILD_SOURCESDIRECTORY = 'TestDrive:\'
        $env:BUILD_BUILDNUMBER = $buildNumber

        It "should apply the correct version when format is '#.#.###'" {
            $versionPattern = '#.#.###'
            # NuGet does not fully support SemVer, so '.' & '+' are replaced with '-'
            $expectedVersion = '1.2.3-ci0008-14331-07'

            ..\src\Update-Version.ps1 -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#.##'" {
            $versionPattern = '#.#.##'
            $expectedVersion = '1.2.3-ci0008'

            ..\src\Update-Version.ps1 -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#.#'" {
            $versionPattern = '#.#.#'
            $expectedVersion = '1.2.3'

            ..\src\Update-Version.ps1 -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.#.0'" {
            $versionPattern = '#.#.0'
            $expectedVersion = '1.2.0'

            ..\src\Update-Version.ps1 -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It "should apply the correct version when format is '#.0.0'" {
            $versionPattern = '#.0.0'
            $expectedVersion = '1.0.0'

            ..\src\Update-Version.ps1 -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }
    }

    Context 'when package-version contains placeholders' {
        $buildNumber = 'Test_2014-11-27'
        $path = 'TestDrive:\package.nuspec'
        $version = '4.3.2.1'

        Set-Content -Path $path -Value $Package_Nuspec

        $env:BUILD_SOURCESDIRECTORY = 'TestDrive:\'
        $env:BUILD_BUILDNUMBER = $buildNumber

        It 'should leave a single placeholder as is' {
            $versionPattern = '#.#.{0}'
            $expectedVersion = '4.3.{0}'

            ..\src\Update-Version.ps1 -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }

        It 'should leave multiple placeholders as is' {
            $versionPattern = '#.{1}#.{0}'
            $expectedVersion = '4.{1}3.{0}'

            ..\src\Update-Version.ps1 -Version $version -PackageVersionPattern $versionPattern

            $actualVersion = Get-PackageVersion -Path $path
            $actualVersion | Should Be $expectedVersion
        }
    }
}
