##-----------------------------------------------------------------------
## <copyright file="PostBuild.Tests.ps1">(c) https://github.com/CodeblackNL/TFSBuildScripts. See https://github.com/CodeblackNL/TFSBuildScripts/blob/master/LICENSE. </copyright>
##-----------------------------------------------------------------------

Remove-Module "Build" -ErrorAction SilentlyContinue
Import-Module "$PSScriptRoot\..\src\Build.psm1"

Describe "PostBuild" {
    Context "when called from the build-workflow" {
        $sut = $PSScriptRoot.Replace("\tests", "\src\PostBuild.ps1")
        $buildNumber = "Test_2014-11-27"
        $sourcesDirectory = "TestDrive:\"
        Mock Import-Module {} -ParameterFilter { $Name -and $Name.EndsWith("\Build.psm1") }
        Mock Get-EnvironmentVariable { return $sourcesDirectory } -ParameterFilter { $Name -eq "TF_BUILD_SOURCESDIRECTORY" } 
        Mock Remove-BOM
        Mock Invoke-SonarRunner

        It "should import the Build module" {
            . $sut

            Assert-MockCalled Import-Module
        }

        It "should retrieve source-directory from environment-variables" {
            . $sut

            Assert-MockCalled Get-EnvironmentVariable -ParameterFilter { $Name -eq "TF_BUILD_SOURCESDIRECTORY" } 
        }

        It "should call Remove-BOM" {
            . $sut

            Assert-MockCalled Remove-BOM
        }

        It "should call Remove-BOM passing SourcesDirectory" {
            . $sut

            Assert-MockCalled Remove-BOM -ParameterFilter { $SourcesDirectory -eq $sourcesDirectory } 
        }

        It "should call Invoke-SonarRunner" {
            . $sut

            Assert-MockCalled Invoke-SonarRunner
        }

        It "should call Invoke-SonarRunner passing SourcesDirectory" {
            . $sut

            Assert-MockCalled Invoke-SonarRunner -ParameterFilter { $SourcesDirectory -eq $sourcesDirectory } 
        }

        It "should call Invoke-SonarRunner passing SonarRunnerBinDirectory" {
            $paramValue = "foo"

            . $sut -SonarRunnerBinDirectory $paramValue

            Assert-MockCalled Invoke-SonarRunner -ParameterFilter { $SonarRunnerBinDirectory -eq $paramValue } 
        }

        It "should call Invoke-SonarRunner passing SonarPropertiesFileName" {
            $paramValue = "foo"

            . $sut -SonarPropertiesFileName $paramValue

            Assert-MockCalled Invoke-SonarRunner -ParameterFilter { $SonarPropertiesFileName -eq $paramValue } 
        }
    }

    Context "when called from the build-workflow, but disabled" {
        $sut = $PSScriptRoot.Replace("\tests", "\src\PostBuild.ps1")
        Mock Remove-BOM
        Mock Invoke-SonarRunner

        It "should not call Remove-BOM or Invoke-SonarRunner" {
            . $sut -Disabled

            Assert-VerifiableMocks
        }
    }
}
