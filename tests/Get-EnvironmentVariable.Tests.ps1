Remove-Module "Build" -ErrorAction SilentlyContinue
Import-Module "$PSScriptRoot\..\src\Build.psm1"

Describe "Get-EnvironmentVariable" {
    Context "when an existing variable is requested" {
        It "should return the requested environment variable" {
            $expectedValue = "TestValue"
            $Env:FooBar = $expectedValue

            $value = Get-EnvironmentVariable -Name "FooBar"

            $value | Should Be $expectedValue
        }
    }
}
