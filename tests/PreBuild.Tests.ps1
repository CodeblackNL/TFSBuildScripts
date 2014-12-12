##-----------------------------------------------------------------------
## <copyright file="PreBuild.Tests.ps1">(c) https://github.com/CodeblackNL/TFSBuildScripts. See https://github.com/CodeblackNL/TFSBuildScripts/blob/master/LICENSE. </copyright>
##-----------------------------------------------------------------------

Remove-Module "Build" -ErrorAction SilentlyContinue
Import-Module "$PSScriptRoot\..\src\Build.psm1"

Describe "PreBuild" {
    $sut = $PSScriptRoot.Replace("\tests", "\src\PreBuild.ps1")
    $buildNumber = "Test_2014-11-27"
    $sourcesDirectory = "TestDrive:\"
    Mock Import-Module {} -ParameterFilter { $Name -and $Name.EndsWith("\Build.psm1") }
    Mock Get-EnvironmentVariable { return $buildNumber } -ParameterFilter { $Name -eq "TF_BUILD_BUILDNUMBER" } 
    Mock Get-EnvironmentVariable { return $sourcesDirectory } -ParameterFilter { $Name -eq "TF_BUILD_SOURCESDIRECTORY" } 
    Mock Update-Version

    Context "when called from the build-workflow" {
        . $sut

        It "should import the Build module" {
            Assert-MockCalled Import-Module
        }

        It "should retrieve build-number from environment-variables" {
            Assert-MockCalled Get-EnvironmentVariable -ParameterFilter { $Name -eq "TF_BUILD_BUILDNUMBER" } 
        }

        It "should retrieve source-directory from environment-variables" {
            Assert-MockCalled Get-EnvironmentVariable -ParameterFilter { $Name -eq "TF_BUILD_SOURCESDIRECTORY" } 
        }

        It "should call Update-Version" {
            Assert-MockCalled Update-Version
        }

        It "should call Update-Version passing SourcesDirectory" {
            Assert-MockCalled Update-Version -ParameterFilter { $SourcesDirectory -eq $sourcesDirectory } 
        }

        It "should call Update-Version passing BuildNumber" {
            Assert-MockCalled Update-Version -ParameterFilter { $BuildNumber -eq $buildNumber } 
        }
    }

    Context "when called from the build-workflow, with specific Version" {
        $paramValue = "1.2.J.B"

        . $sut -Version $paramValue

        It "should call Update-Version passing the specified Version" {
            Assert-MockCalled Update-Version -ParameterFilter { $Version -eq $paramValue } 
        }
    }

    Context "when called from the build-workflow, with specific AssemblyVersionFilePattern" {
        $paramValue = "1.2.J.B"

        . $sut -AssemblyVersionFilePattern $paramValue

        It "should call Update-Version passing the specified AssemblyVersionFilePattern" {
            Assert-MockCalled Update-Version -ParameterFilter { $AssemblyVersionFilePattern -eq $paramValue } 
        }
    }

    Context "when called from the build-workflow, with specific AssemblyVersionPattern" {
        $paramValue = "1.2.#.#"

        . $sut -AssemblyVersionPattern $paramValue

        It "should call Update-Version passing the specified AssemblyVersionPattern" {
            Assert-MockCalled Update-Version -ParameterFilter { $AssemblyVersionPattern -eq $paramValue } 
        }
    }

    Context "when called from the build-workflow, with specific FileVersionPattern" {
        $paramValue = "1.2.#.#"

        . $sut -FileVersionPattern $paramValue

        It "should call Update-Version passing the specified FileVersionPattern" {
            Assert-MockCalled Update-Version -ParameterFilter { $FileVersionPattern -eq $paramValue } 
        }
    }

    Context "when called from the build-workflow, with specific ProductVersionPattern" {
        $paramValue = "1.2.#.#"

        . $sut -ProductVersionPattern $paramValue

        It "should call Update-Version passing the specified ProductVersionPattern" {
            Assert-MockCalled Update-Version -ParameterFilter { $ProductVersionPattern -eq $paramValue } 
        }
    }

    Context "when called from the build-workflow, with specific PackageVersionPattern" {
        $paramValue = "1.2.#.#"

        . $sut -PackageVersionPattern $paramValue

        It "should call Update-Version passing the specified PackageVersionPattern" {
            Assert-MockCalled Update-Version -ParameterFilter { $PackageVersionPattern -eq $paramValue } 
        }
    }

    Context "when called from the build-workflow, but disabled" {
        . $sut -Disabled

        It "should not call Update-Version" {
            Assert-VerifiableMocks
        }
    }
}
