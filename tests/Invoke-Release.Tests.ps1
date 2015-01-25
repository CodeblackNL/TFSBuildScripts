##-----------------------------------------------------------------------
## <copyright file="Get-EnvironmentVariable.Tests.ps1">(c) https://github.com/CodeblackNL/TFSBuildScripts. See https://github.com/CodeblackNL/TFSBuildScripts/blob/master/LICENSE. </copyright>
##-----------------------------------------------------------------------

Remove-Module "Build" -ErrorAction SilentlyContinue
Import-Module "$PSScriptRoot\..\src\Build.psm1"

Describe "Invoke-Release" {
    Context "when called" {
        $rmServer = "rm-test"
        $tfsUrl = "http://tfs-test:8080/tfs/DefaultCollection"
        $teamProjectName = "test-project"
        $buildDefinitionName = "test-build"
        $buildNumber = "test-build_1.2.3.4"
        $targetStageName = "Production"

        $baseUrl = "http://rm-test:1000/account/releaseManagementService/_apis/releaseManagement/OrchestratorService"
        $expectedInitiateUrl += "$baseUrl/InitiateReleaseFromBuild"
        $expectedInitiateUrl +=	"?teamFoundationServerUrl=$([System.Uri]::EscapeDataString($tfsUrl))"
        $expectedInitiateUrl +=	"&teamProject=$teamProjectName"
        $expectedInitiateUrl +=	"&buildDefinition=$buildDefinitionName"
        $expectedInitiateUrl +=	"&buildNumber=$buildNumber"
        $expectedInitiateUrl +=	"&targetStageName=$targetStageName"
        $expectedStatusUrl = "$baseUrl/ReleaseStatus?releaseId=42"

        Mock -ModuleName Build -CommandName Invoke-RestMethod -MockWith { }
        Mock -ModuleName Build -CommandName Invoke-RestMethod -MockWith { return 42 } -ParameterFilter { $Uri -eq $expectedInitiateUrl -and $Method -eq 'Get' }
        Mock -ModuleName Build -CommandName Invoke-RestMethod -MockWith { return 2 } -ParameterFilter { $Uri -eq $expectedStatusUrl -and $Method -eq 'Get' }

        Invoke-Release -RMServer $rmServer `
                       -TeamFoundationServerUrl $tfsUrl -TeamProjectName $teamProjectName `
                       -BuildDefinitionName $buildDefinitionName -BuildNumber $buildNumber `
                       -TargetStageName $targetStageName

        It "should initiate release" {
            Assert-MockCalled Invoke-RestMethod -ModuleName Build -ParameterFilter { $Uri -eq $expectedInitiateUrl -and $Method -eq 'Get' }
        }

        It "should retrieve release status" {
            Assert-MockCalled Invoke-RestMethod -ModuleName Build -ParameterFilter { $Uri -eq $expectedStatusUrl -and $Method -eq 'Get' }
        }
    }
}
