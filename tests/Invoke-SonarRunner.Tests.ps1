##-----------------------------------------------------------------------
## <copyright file="Get-EnvironmentVariable.Tests.ps1">(c) https://github.com/CodeblackNL/TFSBuildScripts. See https://github.com/CodeblackNL/TFSBuildScripts/blob/master/LICENSE. </copyright>
##-----------------------------------------------------------------------

Remove-Module "Build" -ErrorAction SilentlyContinue
Import-Module "$PSScriptRoot\..\src\Build.psm1"

Describe "Invoke-SonarRunner" {
    Context "when called with defaults" {
		$sourcesDirectory = "TestDrive:\src"
		$defaultPropertiesFilePath = Join-Path $sourcesDirectory "sonar-project.properties"
		Mock Test-Path -ModuleName Build { return $true }
		Mock Invoke-Process -ModuleName Build { }

		Invoke-SonarRunner -SourcesDirectory $sourcesDirectory

        It "should invoke sonar-runner" {
			Assert-MockCalled Invoke-Process -ModuleName Build
        }

        It "should invoke sonar-runner with default file-path" {
			Assert-MockCalled Invoke-Process -ModuleName Build -ParameterFilter { $FilePath -eq "C:\sonar\bin\sonar-runner.bat" }
        }

        It "should invoke sonar-runner with sources-directory as working-directory" {
			Assert-MockCalled Invoke-Process -ModuleName Build -ParameterFilter { $WorkingDirectory -eq $sourcesDirectory }
        }

        It "should invoke sonar-runner with default properties-file" {
			Assert-MockCalled Invoke-Process -ModuleName Build -ParameterFilter { $Arguments -eq "-Dproject.settings='$defaultPropertiesFilePath'" }
        }
    }

	Context "when sonar-runner not present" {
		$sourcesDirectory = "TestDrive:\src"
		Mock Test-Path -ModuleName Build { return $true }
		Mock Test-Path -ModuleName Build { return $false } -ParameterFilter { $Path -eq "C:\sonar\bin\sonar-runner.bat" }
		Mock Invoke-Process -ModuleName Build { }

		Invoke-SonarRunner -SourcesDirectory $sourcesDirectory

		It "should not invoke sonar-runner" {
			Assert-MockCalled Invoke-Process -ModuleName Build -Times 0
		}
	}

	Context "when properties-file not present" {
		$sourcesDirectory = "TestDrive:\src"
		$defaultPropertiesFilePath = Join-Path $sourcesDirectory "sonar-project.properties"
		Mock Test-Path -ModuleName Build { return $true }
		Mock Test-Path -ModuleName Build { return $false } -ParameterFilter { $Path -eq $defaultPropertiesFilePath }
		Mock Get-ChildItem -ModuleName Build { return @{} }
		Mock Invoke-Process -ModuleName Build { }

		Invoke-SonarRunner -SourcesDirectory $sourcesDirectory

		It "should not invoke sonar-runner" {
			Assert-MockCalled Invoke-Process -ModuleName Build -Times 0
		}
	}

    Context "when bin-directory provided" {
		$sourcesDirectory = "TestDrive:\src"
		$sonarRunnerBinDirectory = "C:\Program Files\Sonar\bin"
		Mock Test-Path -ModuleName Build { return $true }
		Mock Invoke-Process -ModuleName Build { }

		Invoke-SonarRunner -SourcesDirectory $sourcesDirectory -SonarRunnerBinDirectory $sonarRunnerBinDirectory

        It "should invoke sonar-runner with file-path containing requested directory" {
			Assert-MockCalled Invoke-Process -ModuleName Build -ParameterFilter { $FilePath -eq (Join-Path $sonarRunnerBinDirectory "sonar-runner.bat") }
        }
    }

    Context "when sonar-properties provided" {
		$sourcesDirectory = "TestDrive:\src"
		$propertiesFileName = "project.sonar"
		$propertiesFilePath = Join-Path $sourcesDirectory $propertiesFileName
		Mock Test-Path -ModuleName Build { return $true }
		Mock Invoke-Process -ModuleName Build { }

		Invoke-SonarRunner -SourcesDirectory $sourcesDirectory -SonarPropertiesFileName $propertiesFileName

        It "should invoke sonar-runner" {
			Assert-MockCalled Invoke-Process -ModuleName Build
        }

        It "should invoke sonar-runner with default file-path" {
			Assert-MockCalled Invoke-Process -ModuleName Build -ParameterFilter { $FilePath -eq "C:\sonar\bin\sonar-runner.bat" }
        }

        It "should invoke sonar-runner with sources-directory as working-directory" {
			Assert-MockCalled Invoke-Process -ModuleName Build -ParameterFilter { $WorkingDirectory -eq $sourcesDirectory }
        }

        It "should invoke sonar-runner with provided sonar-properties file" {
			Assert-MockCalled Invoke-Process -ModuleName Build -ParameterFilter { $Arguments -eq "-Dproject.settings='$propertiesFilePath'" }
        }
    }

    Context "when called with WhatIf" {
		$sourcesDirectory = "TestDrive:\src"
		Mock Test-Path -ModuleName Build { return $true }
		Mock Invoke-Process -ModuleName Build { }

		Invoke-SonarRunner -SourcesDirectory $sourcesDirectory -WhatIf

        It "should not call Invoke-Process" {
			Assert-MockCalled Invoke-Process -ModuleName Build -Times 0
        }
    }
}
