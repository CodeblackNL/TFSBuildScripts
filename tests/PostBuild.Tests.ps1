##-----------------------------------------------------------------------
## <copyright file="PostBuild.Tests.ps1">(c) https://github.com/CodeblackNL/TFSBuildScripts. See https://github.com/CodeblackNL/TFSBuildScripts/blob/master/LICENSE. </copyright>
##-----------------------------------------------------------------------

Remove-Module "Build" -ErrorAction SilentlyContinue
Import-Module "$PSScriptRoot\..\src\Build.psm1"

Describe "PostBuild" {
    $sut = $PSScriptRoot.Replace("\tests", "\src\PostBuild.ps1")
    $sourcesDirectory = "TestDrive:\"
    Mock Import-Module {} -ParameterFilter { $Name -and $Name.EndsWith("\Build.psm1") }
    Mock Get-EnvironmentVariable { return $sourcesDirectory } -ParameterFilter { $Name -eq "TF_BUILD_SOURCESDIRECTORY" } 
    Mock Remove-BOM
    Mock Invoke-SonarRunner

    Context "when called from the build-workflow" {
        . $sut

        It "should import the Build module" {
            Assert-MockCalled Import-Module
        }

        It "should retrieve source-directory from environment-variables" {
            Assert-MockCalled Get-EnvironmentVariable -ParameterFilter { $Name -eq "TF_BUILD_SOURCESDIRECTORY" } 
        }

        It "should call Remove-BOM" {
            Assert-MockCalled Remove-BOM
        }

        It "should call Remove-BOM passing SourcesDirectory" {
            Assert-MockCalled Remove-BOM -ParameterFilter { $SourcesDirectory -eq $sourcesDirectory } 
        }

        It "should call Invoke-SonarRunner" {
            Assert-MockCalled Invoke-SonarRunner
        }

        It "should call Invoke-SonarRunner passing SourcesDirectory" {
            Assert-MockCalled Invoke-SonarRunner -ParameterFilter { $SourcesDirectory -eq $sourcesDirectory } 
        }
    }

    Context "when called from the build-workflow, with specific SonarRunnerBinDirectory" {
        $paramValue = "foo"

        . $sut -SonarRunnerBinDirectory $paramValue

        It "should call Invoke-SonarRunner passing the specified SonarRunnerBinDirectory" {
            Assert-MockCalled Invoke-SonarRunner -ParameterFilter { $SonarRunnerBinDirectory -eq $paramValue } 
        }
    }

    Context "when called from the build-workflow, with specific SonarPropertiesFileName" {
        $paramValue = "foo"

        . $sut -SonarPropertiesFileName $paramValue

        It "should call Invoke-SonarRunner passing the specified SonarPropertiesFileName" {
            Assert-MockCalled Invoke-SonarRunner -ParameterFilter { $SonarPropertiesFileName -eq $paramValue } 
        }
    }

    Context "when called from the build-workflow, but disabled" {
        Mock Remove-BOM
        Mock Invoke-SonarRunner

        . $sut -Disabled

        It "should not call Remove-BOM or Invoke-SonarRunner" {
            Assert-VerifiableMocks
        }
    }
}
