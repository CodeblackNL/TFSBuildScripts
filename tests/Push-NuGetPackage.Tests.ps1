##-----------------------------------------------------------------------
## <copyright file="Push-NuGetPackage.Tests.ps1">(c) https://github.com/CodeblackNL/TFSBuildScripts. See https://github.com/CodeblackNL/TFSBuildScripts/blob/master/LICENSE. </copyright>
##-----------------------------------------------------------------------

Remove-Module "Build" -ErrorAction SilentlyContinue
Import-Module "$PSScriptRoot\..\src\Build.psm1"

$Package1_Data = @'
{
  "NugetFilePath": "TestDrive:\\a_path\\nuget.exe"
}
'@
$Package2_Data = @'
{
  "NugetFilePath": "TestDrive:\\another_path\\nuget.exe"
}
'@

Describe "Push-NuGetPackage" {
	$dropDirectory = "TestDrive:\drop"
	New-Item $dropDirectory -ItemType Container
	New-Item "$dropDirectory\Package" -ItemType Container
    Set-Content -Path "TestDrive:\drop\Package\package1.nupkg" -Value "."
    Set-Content -Path "TestDrive:\drop\Package\package2.nupkg" -Value "."
    Set-Content -Path "TestDrive:\drop\Package\package1.json" -Value $Package1_Data
    Set-Content -Path "TestDrive:\drop\Package\package2.json" -Value $Package2_Data
    $packageSource = "\\localhost\packages"
	$key = "B359186E-4D18-4C56-999D-D27639418A6F"

	Mock Invoke-Process -ModuleName Build { }

	Context "when called with defaults" {
		Push-NuGetPackage -DropDirectory $dropDirectory -Source $packageSource

		It "should use correct default output-path" {
			Assert-MockCalled Invoke-Process -ModuleName Build -Times 2 -ParameterFilter { $Arguments -match ".*\\drop\\Package\\package[\d]?.nupkg" }
		}

		It "should process all packages in the output-path" {
			Assert-MockCalled Invoke-Process -ModuleName Build -Times 1 -ParameterFilter { $Arguments -match ".*\\drop\\Package\\package1.nupkg" }
			Assert-MockCalled Invoke-Process -ModuleName Build -Times 1 -ParameterFilter { $Arguments -match ".*\\drop\\Package\\package2.nupkg" }
		}

		It "should use correct nuget.exe for each package" {
			Assert-MockCalled Invoke-Process -ModuleName Build -Times 1 -ParameterFilter { $Arguments -match ".*\\drop\\Package\\package1.nupkg" -and $FilePath -eq "TestDrive:\a_path\nuget.exe" }
			Assert-MockCalled Invoke-Process -ModuleName Build -Times 1 -ParameterFilter { $Arguments -match ".*\\drop\\Package\\package2.nupkg" -and $FilePath -eq "TestDrive:\another_path\nuget.exe" }
		}

		It "should use correct nuget.exe for each package" {
			Assert-MockCalled Invoke-Process -ModuleName Build -Times 1 -ParameterFilter { $Arguments -match ".*\\drop\\Package\\package1.nupkg" -and $FilePath -eq "TestDrive:\a_path\nuget.exe" }
			Assert-MockCalled Invoke-Process -ModuleName Build -Times 1 -ParameterFilter { $Arguments -match ".*\\drop\\Package\\package2.nupkg" -and $FilePath -eq "TestDrive:\another_path\nuget.exe" }
		}

		It "should use source for each package" {
			Assert-MockCalled Invoke-Process -ModuleName Build -Times 1 -ParameterFilter { $Arguments -match ".*\\drop\\Package\\package1.nupkg" -and $Arguments -match "-Source `"\\\\localhost\\packages`"" }
			Assert-MockCalled Invoke-Process -ModuleName Build -Times 1 -ParameterFilter { $Arguments -match ".*\\drop\\Package\\package2.nupkg" -and $Arguments -match "-Source `"\\\\localhost\\packages`"" }
		}
	}

	Context "when called with api-key" {
		Push-NuGetPackage -DropDirectory $dropDirectory -Source $packageSource -ApiKey $key

		It "should use the api-key for each package" {
			Assert-MockCalled Invoke-Process -ModuleName Build -Times 1 -ParameterFilter { $Arguments -match ".*\\drop\\Package\\package1.nupkg" -and $Arguments -match $key }
			Assert-MockCalled Invoke-Process -ModuleName Build -Times 1 -ParameterFilter { $Arguments -match ".*\\drop\\Package\\package2.nupkg" -and $Arguments -match $key }
		}
    }

	Context "when called without source" {
		Push-NuGetPackage -DropDirectory $dropDirectory

		It "should not push any packages" {
			Assert-MockCalled Invoke-Process -ModuleName Build -Times 0
		}
    }

	Context "when called with specific output-path" {
    	New-Item "$dropDirectory\OtherFolder" -ItemType Container
        Set-Content -Path "TestDrive:\drop\OtherFolder\package1.nupkg" -Value "."
        Set-Content -Path "TestDrive:\drop\OtherFolder\package2.nupkg" -Value "."
        Set-Content -Path "TestDrive:\drop\OtherFolder\package1.json" -Value $Package1_Data
        Set-Content -Path "TestDrive:\drop\OtherFolder\package2.json" -Value $Package2_Data

		Push-NuGetPackage -DropDirectory $dropDirectory -OutputPath "OtherFolder" -Source $packageSource

		It "should use correct output-path" {
			Assert-MockCalled Invoke-Process -ModuleName Build -Times 2 -ParameterFilter { $Arguments -match ".*\\drop\\OtherFolder\\package[\d]?.nupkg" }
		}
	}

    Context "when called with WhatIf" {
		Push-NuGetPackage -DropDirectory $dropDirectory -Source $packageSource -WhatIf

        It "should not call Invoke-Process" {
			Assert-MockCalled Invoke-Process -ModuleName Build -Times 0
        }
    }
}
