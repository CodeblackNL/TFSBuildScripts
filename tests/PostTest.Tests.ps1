##-----------------------------------------------------------------------
## <copyright file="PostTest.Tests.ps1">(c) https://github.com/CodeblackNL/TFSBuildScripts. See https://github.com/CodeblackNL/TFSBuildScripts/blob/master/LICENSE. </copyright>
##-----------------------------------------------------------------------

Remove-Module "Build" -ErrorAction SilentlyContinue
Import-Module "$PSScriptRoot\..\src\Build.psm1"

Describe "PostTest" {
    $sut = $PSScriptRoot.Replace("\tests", "\src\PostTest.ps1")
    $srcPath = "TestDrive:\src"
    $binPath = "TestDrive:\bin"
    $dropPath = "TestDrive:\drop"
    $collectionUrl = "http://localhost:8080/tfs/DefaultCollection/"
    $buildUrl = "vstfs:///Build/Build/174"
	$buildDefinitionName = "test-build"
	$buildNumber = "test-build_1.2.15025.1008"
    $rmServer = "rm-test"
	$targetStageName = "prod"
	$filePath = "some-location\some.nuspec"
    $baseFolder = "PrePackage"
    $outputFolder = "Package"
    $packageSource = "\\localhost\packages"
    $key = "B359186E-4D18-4C56-999D-D27639418A6F"

    Mock Import-Module {} -ParameterFilter { $Name -and $Name.EndsWith("\Build.psm1") }
    Mock Get-EnvironmentVariable { return $srcPath } -ParameterFilter { $Name -eq "TF_BUILD_SOURCESDIRECTORY" }
    Mock Get-EnvironmentVariable { return $binPath } -ParameterFilter { $Name -eq "TF_BUILD_BINARIESDIRECTORY" }
    Mock Get-EnvironmentVariable { return $dropPath } -ParameterFilter { $Name -eq "TF_BUILD_DROPLOCATION" } 
    Mock Get-EnvironmentVariable { return $collectionUrl } -ParameterFilter { $Name -eq "TF_BUILD_COLLECTIONURI" }
    Mock Get-EnvironmentVariable { return $buildUrl } -ParameterFilter { $Name -eq "TF_BUILD_BUILDURI" }
    Mock Get-EnvironmentVariable { return $buildDefinitionName } -ParameterFilter { $Name -eq "TF_BUILD_BUILDDEFINITIONNAME" }
    Mock Get-EnvironmentVariable { return $buildNumber } -ParameterFilter { $Name -eq "TF_BUILD_BUILDNUMBER" }
	Mock Invoke-Release
    Mock New-NuGetPackage
    Mock Push-NuGetPackage

    Context "when called from the build-workflow to invoke release" {
        Mock Get-Build { return @{ CompilationStatus = "Succeeded"; TestStatus = "Succeeded"; TeamProject = "TestProject" } }

        . $sut -NuspecFilePath $filePath -BasePath $baseFolder -OutputPath $outputFolder `
		       -Release -RMServer $rmServer -TargetStageName $targetStageName

        It "should import the Build module" {
            Assert-MockCalled Import-Module
        }

        It "should retrieve collection-uri from environment-variables" {
            Assert-MockCalled Get-EnvironmentVariable -ParameterFilter { $Name -eq "TF_BUILD_COLLECTIONURI" } 
        }

        It "should retrieve build-uri from environment-variables" {
            Assert-MockCalled Get-EnvironmentVariable -ParameterFilter { $Name -eq "TF_BUILD_BUILDURI" } 
        }

        It "should retrieve build-definition-name from environment-variables" {
            Assert-MockCalled Get-EnvironmentVariable -ParameterFilter { $Name -eq "TF_BUILD_BUILDDEFINITIONNAME" } 
        }

        It "should retrieve build-number from environment-variables" {
            Assert-MockCalled Get-EnvironmentVariable -ParameterFilter { $Name -eq "TF_BUILD_BUILDNUMBER" } 
        }

        It "should retrieve build-details" {
            Assert-MockCalled Get-Build -ParameterFilter { $CollectionUri -eq $collectionUrl -and $BuildUri -eq $buildUrl }
        }

        It "should invoke release" {
            Assert-MockCalled Invoke-Release -ParameterFilter { $RMServer -eq $rmServer -and `
																$RMPort -eq 1000 -and `
                                                                $TeamFoundationServerUrl -eq $collectionUrl -and `
                                                                $TeamProjectName -eq "TestProject" -and `
                                                                $BuildDefinitionName -eq $buildDefinitionName -and `
                                                                $BuildNumber -eq $buildNumber -and `
                                                                $TargetStageName -eq $targetStageName }
        }
    }

    Context "when called from the build-workflow to create package" {
        Mock Get-Build { return @{ CompilationStatus = "Succeeded"; TestStatus = "Succeeded" } }

        . $sut -NuspecFilePath $filePath -BasePath $baseFolder -OutputPath $outputFolder `
		       -Package

        It "should import the Build module" {
            Assert-MockCalled Import-Module
        }

        It "should retrieve source-directory from environment-variables" {
            Assert-MockCalled Get-EnvironmentVariable -ParameterFilter { $Name -eq "TF_BUILD_SOURCESDIRECTORY" } 
        }

        It "should retrieve binaries-directory from environment-variables" {
            Assert-MockCalled Get-EnvironmentVariable -ParameterFilter { $Name -eq "TF_BUILD_BINARIESDIRECTORY" } 
        }

        It "should retrieve drop-directory from environment-variables" {
            Assert-MockCalled Get-EnvironmentVariable -ParameterFilter { $Name -eq "TF_BUILD_DROPLOCATION" } 
        }

        It "should retrieve collection-uri from environment-variables" {
            Assert-MockCalled Get-EnvironmentVariable -ParameterFilter { $Name -eq "TF_BUILD_COLLECTIONURI" } 
        }

        It "should retrieve build-uri from environment-variables" {
            Assert-MockCalled Get-EnvironmentVariable -ParameterFilter { $Name -eq "TF_BUILD_BUILDURI" } 
        }

        It "should retrieve build-details" {
            Assert-MockCalled Get-Build -ParameterFilter { $CollectionUri -eq $collectionUrl -and $BuildUri -eq $buildUrl }
        }

        It "should create package(s)" {
            Assert-MockCalled New-NuGetPackage -ParameterFilter { $SourcesDirectory -eq $srcPath -and `
																  $BinariesDirectory -eq $binPath -and `
                                                                  $DropDirectory -eq $dropPath -and `
                                                                  $NuspecFilePath -eq $filePath -and `
                                                                  $BasePath -eq $baseFolder -and `
                                                                  $OutputPath -eq $outputFolder }
        }
    }

    Context "when called from the build-workflow to push package" {
        Mock Get-Build { return @{ CompilationStatus = "Succeeded"; TestStatus = "Succeeded" } }

        . $sut -NuspecFilePath $filePath -BasePath $baseFolder -OutputPath $outputFolder `
		       -Package -Push -Source $packageSource -ApiKey $key

        It "should import the Build module" {
            Assert-MockCalled Import-Module
        }

        It "should retrieve source-directory from environment-variables" {
            Assert-MockCalled Get-EnvironmentVariable -ParameterFilter { $Name -eq "TF_BUILD_SOURCESDIRECTORY" } 
        }

        It "should retrieve binaries-directory from environment-variables" {
            Assert-MockCalled Get-EnvironmentVariable -ParameterFilter { $Name -eq "TF_BUILD_BINARIESDIRECTORY" } 
        }

        It "should retrieve drop-directory from environment-variables" {
            Assert-MockCalled Get-EnvironmentVariable -ParameterFilter { $Name -eq "TF_BUILD_DROPLOCATION" } 
        }

        It "should retrieve collection-uri from environment-variables" {
            Assert-MockCalled Get-EnvironmentVariable -ParameterFilter { $Name -eq "TF_BUILD_COLLECTIONURI" } 
        }

        It "should retrieve build-uri from environment-variables" {
            Assert-MockCalled Get-EnvironmentVariable -ParameterFilter { $Name -eq "TF_BUILD_BUILDURI" } 
        }

        It "should retrieve build-details" {
            Assert-MockCalled Get-Build -ParameterFilter { $CollectionUri -eq $collectionUrl -and $BuildUri -eq $buildUrl }
        }

        It "should create package(s)" {
            Assert-MockCalled New-NuGetPackage -ParameterFilter { $SourcesDirectory -eq $srcPath -and `
																  $BinariesDirectory -eq $binPath -and `
                                                                  $DropDirectory -eq $dropPath -and `
                                                                  $NuspecFilePath -eq $filePath -and `
                                                                  $BasePath -eq $baseFolder -and `
                                                                  $OutputPath -eq $outputFolder }
        }

        It "should push package(s)" {
            Assert-MockCalled Push-NuGetPackage -ParameterFilter { $OutputPath -eq $outputFolder -and `
                                                                   $Source -eq $packageSource -and `
                                                                   $ApiKey -eq $key }
        }
    }

    Context "when package is not enabled" {
        Mock Get-Build { return @{ CompilationStatus = "Succeeded"; TestStatus = "Succeeded" } }

        . $sut -Source $packageSource -ApiKey $key

        It "should not create package(s)" {
            Assert-MockCalled New-NuGetPackage -Times 0
        }

        It "should not push package(s)" {
            Assert-MockCalled Push-NuGetPackage -Times 0
        }
    }

    Context "when only push is not enabled" {
        Mock Get-Build { return @{ CompilationStatus = "Succeeded"; TestStatus = "Succeeded" } }

        . $sut -Source $packageSource -ApiKey $key -Package

        It "should create package(s)" {
            Assert-MockCalled New-NuGetPackage
        }

        It "should not push package(s)" {
            Assert-MockCalled Push-NuGetPackage -Times 0
        }
    }

    Context "when the build failed during compilation" {
        Mock Get-Build { return @{ CompilationStatus = "Failed"; TestStatus = "Succeeded" } }

        . $sut -Package -Push -Release

        It "should not invoke release" {
            Assert-MockCalled Get-Build
            Assert-VerifiableMocks
        }

        It "should not create or push packages" {
            Assert-MockCalled Get-Build
            Assert-VerifiableMocks
        }
    }

    Context "when the build failed during test" {
        Mock Get-Build { return @{ CompilationStatus = "Succeeded"; TestStatus = "Failed" } }

        . $sut -Package -Push -Release

        It "should not invoke release" {
            Assert-MockCalled Get-Build
            Assert-VerifiableMocks
        }

        It "should not create or push packages" {
            Assert-MockCalled Get-Build
            Assert-VerifiableMocks
        }
    }

    Context "when called from the build-workflow, but disabled" {
        Mock Get-Build { }

        . $sut -Disabled

        It "should not call Get-Build, invoke release, or create/push packages" {
            Assert-VerifiableMocks
        }
    }
}
