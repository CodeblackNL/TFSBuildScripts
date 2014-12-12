##-----------------------------------------------------------------------
## <copyright file="New-NuGetPackage.Tests.ps1">(c) https://github.com/CodeblackNL/TFSBuildScripts. See https://github.com/CodeblackNL/TFSBuildScripts/blob/master/LICENSE. </copyright>
##-----------------------------------------------------------------------

Remove-Module "Build" -ErrorAction SilentlyContinue
Import-Module "$PSScriptRoot\..\src\Build.psm1"

$Package_1_Nuspec = @'
<?xml version="1.0"?>
<package>
  <metadata>
    <id>Test01</id>
    <version>2.1.4</version>
    <authors>Jeroen Swart</authors>
    <description>Package Test 1.</description>
  </metadata>
</package>
'@
$Package_2_Nuspec = @'
<?xml version="1.0"?>
<package>
  <metadata>
    <id>Test02</id>
    <version>3.4.8</version>
    <authors>Jeroen Swart</authors>
    <description>Package Test 2.</description>
  </metadata>
</package>
'@

Describe "New-NuGetPackage" {
	$sourcesDirectory = "TestDrive:\src"
	$binariesDirectory = "TestDrive:\bin"
	$dropDirectory = "TestDrive:\drop"
	New-Item $sourcesDirectory -ItemType Container
	New-Item $binariesDirectory -ItemType Container
	New-Item $dropDirectory -ItemType Container
    $path1 = "TestDrive:\src\package1.nuspec"
    $path2 = "TestDrive:\src\package2.nuspec"
    Set-Content -Path $path1 -Value $Package1_Nuspec
    Set-Content -Path $path2 -Value $Package2_Nuspec
	Mock Test-Path -ModuleName Build { return $true } -ParameterFilter { $Path -eq "TestDrive:\src\nuget.exe" }
	Mock Invoke-Process -ModuleName Build { }

	Context "when called with defaults" {
		New-NuGetPackage -SourcesDirectory $sourcesDirectory -BinariesDirectory $binariesDirectory -DropDirectory $dropDirectory

		It "should use correct default output-path" {
			Assert-MockCalled Invoke-Process -ModuleName Build -ParameterFilter { $Arguments -match "-BasePath `".*\\Package\\?`"" }
		}
	}

	Context "when called before drop-directory is populated" {
		New-NuGetPackage -SourcesDirectory $sourcesDirectory -BinariesDirectory $binariesDirectory -DropDirectory $dropDirectory

		It "should use binaries-directory as base-path" {
			Assert-MockCalled Invoke-Process -ModuleName Build -ParameterFilter { $Arguments -match "-BasePath `".*\\bin\\?`"" }
		}
	}

	Context "when called after drop-directory is populated" {
        Set-Content -Path "$dropDirectory\dummy.txt" -Value ""

		New-NuGetPackage -SourcesDirectory $sourcesDirectory -BinariesDirectory $binariesDirectory -DropDirectory $dropDirectory

		It "should use drop-directory as base-path" {
			Assert-MockCalled Invoke-Process -ModuleName Build -ParameterFilter { $Arguments -match "-BasePath `".*\\drop\\?`"" }
		}
	}

	Context "when called without specific nuspec-file" {
		New-NuGetPackage -SourcesDirectory $sourcesDirectory -BinariesDirectory $binariesDirectory -DropDirectory $dropDirectory

		It "should create packages for all available nuspec-files" {
			Assert-MockCalled Invoke-Process -ModuleName Build -ParameterFilter { $Arguments.Contains("\src\package1.nuspec") }
			Assert-MockCalled Invoke-Process -ModuleName Build -ParameterFilter { $Arguments.Contains("\src\package2.nuspec") }
		}
	}

	Context "when called with specific nuspec-file" {
		New-NuGetPackage -SourcesDirectory $sourcesDirectory -BinariesDirectory $binariesDirectory -DropDirectory $dropDirectory -NuspecFilePath "package1.nuspec"

		It "should only create packages for specified nuspec-files" {
			Assert-MockCalled Invoke-Process -ModuleName Build -ParameterFilter { $Arguments.Contains("\src\package1.nuspec") }
			Assert-MockCalled Invoke-Process -ModuleName Build -Times 0 -ParameterFilter { $Arguments.Contains("\src\package2.nuspec") }
		}
	}

	Context "when called with specific base-path" {
		$basePath = "PrePackage"

		New-NuGetPackage -SourcesDirectory $sourcesDirectory -BinariesDirectory $binariesDirectory -DropDirectory $dropDirectory -BasePath $basePath

		It "should use correct base-path" {
			Assert-MockCalled Invoke-Process -ModuleName Build -ParameterFilter { $Arguments -match "-BasePath `".*\\$basePath\\?`"" }
		}
	}

	Context "when called with specific output-path" {
		$outputPath = "NuGet"

		New-NuGetPackage -SourcesDirectory $sourcesDirectory -BinariesDirectory $binariesDirectory -DropDirectory $dropDirectory -OutputPath $outputPath

		It "should use correct output-path" {
			Assert-MockCalled Invoke-Process -ModuleName Build -ParameterFilter { $Arguments -match "-BasePath `".*\\$outputPath\\?`"" }
		}
	}

    Context "when called with WhatIf" {
		New-NuGetPackage -SourcesDirectory $sourcesDirectory -BinariesDirectory $binariesDirectory -DropDirectory $dropDirectory -WhatIf

        It "should not call Invoke-Process" {
			Assert-MockCalled Invoke-Process -ModuleName Build -Times 0
        }
    }
}
