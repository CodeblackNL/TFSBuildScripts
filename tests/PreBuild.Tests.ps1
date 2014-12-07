##-----------------------------------------------------------------------
## <copyright file="PreBuild.Tests.ps1">(c) https://github.com/CodeblackNL/TFSBuildScripts. See https://github.com/CodeblackNL/TFSBuildScripts/blob/master/LICENSE. </copyright>
##-----------------------------------------------------------------------

Remove-Module "Build" -ErrorAction SilentlyContinue
Import-Module "$PSScriptRoot\..\src\Build.psm1"

Describe "PreBuild" {
    Context "when called from the build-workflow" {
        $sut = $PSScriptRoot.Replace("\tests", "\src\PreBuild.ps1")
        $buildNumber = "Test_2014-11-27"
        $sourcesDirectory = "TestDrive:\"
        Mock Import-Module {} -ParameterFilter { $Name -and $Name.EndsWith("\Build.psm1") }
        Mock Get-EnvironmentVariable { return $buildNumber } -ParameterFilter { $Name -eq "TF_BUILD_BUILDNUMBER" } 
        Mock Get-EnvironmentVariable { return $sourcesDirectory } -ParameterFilter { $Name -eq "TF_BUILD_SOURCESDIRECTORY" } 
        Mock Update-Version

        It "should import the Build module" {
            . $sut

            Assert-MockCalled Import-Module
        }

        It "should retrieve build-number from environment-variables" {
            . $sut

            Assert-MockCalled Get-EnvironmentVariable -ParameterFilter { $Name -eq "TF_BUILD_BUILDNUMBER" } 
        }

        It "should retrieve source-directory from environment-variables" {
            . $sut

            Assert-MockCalled Get-EnvironmentVariable -ParameterFilter { $Name -eq "TF_BUILD_SOURCESDIRECTORY" } 
        }

        It "should call Update-Version" {
            . $sut

            Assert-MockCalled Update-Version
        }

        It "should call Update-Version passing SourcesDirectory" {
            . $sut

            Assert-MockCalled Update-Version -ParameterFilter { $SourcesDirectory -eq $sourcesDirectory } 
        }

        It "should call Update-Version passing BuildNumber" {
            . $sut

            Assert-MockCalled Update-Version -ParameterFilter { $BuildNumber -eq $buildNumber } 
        }

        It "should call Update-Version passing AssemblyVersionFilePattern" {
            $paramValue = "foo"

            . $sut -AssemblyVersionFilePattern $paramValue

            Assert-MockCalled Update-Version -ParameterFilter { $AssemblyVersionFilePattern -eq $paramValue } 
        }

        It "should call Update-Version passing Version" {
            $paramValue = "1.2.J.B"

            . $sut -Version $paramValue

            Assert-MockCalled Update-Version -ParameterFilter { $Version -eq $paramValue } 
        }

        It "should call Update-Version passing AssemblyVersionPattern" {
            $paramValue = "1.2.#.#"

            . $sut -AssemblyVersionPattern $paramValue

            Assert-MockCalled Update-Version -ParameterFilter { $AssemblyVersionPattern -eq $paramValue } 
        }

        It "should call Update-Version passing FileVersionPattern" {
            $paramValue = "1.2.#.#"

            . $sut -FileVersionPattern $paramValue

            Assert-MockCalled Update-Version -ParameterFilter { $FileVersionPattern -eq $paramValue } 
        }

        It "should call Update-Version passing ProductVersionPattern" {
            $paramValue = "1.2.#.#"

            . $sut -ProductVersionPattern $paramValue

            Assert-MockCalled Update-Version -ParameterFilter { $ProductVersionPattern -eq $paramValue } 
        }
    }

    Context "when called from the build-workflow, but disabled" {
        $sut = $PSScriptRoot.Replace("\tests", "\src\PreBuild.ps1")
        Mock Update-Version

        It "should not call Update-Version" {
            . $sut -Disabled

            Assert-VerifiableMocks
        }
    }
}
