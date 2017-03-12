
$version = $env:BUILD_BUILDNUMBER.Split('_') | Select-Object -Last 1
$nuspecFilePath = Join-Path -Path $PSScriptRoot -ChildPath '..\nuget\TFSBuildScripts.nuspec'

[xml]$nuspec = Get-Content -Path $nuspecFilePath
$nuspec.package.metadata.version = "$version"
$nuspec.Save($nuspecFilePath)
