param (
    [Parameter(Mandatory = $true)]
    $Version,
    [Parameter(Mandatory = $true)]
    $ReleaseVersion,
    [Parameter(Mandatory = $true)]
    $ApiKey
)

try {
    # nuget.exe should be in same directory as this script; needed for creating & publishing the release-package
    $nugetFilePath = Join-Path -Path $PSScriptRoot -ChildPath 'nuget.exe'

    # create directory in temp-folder for downloading & extracting package
    $tempPath = [System.IO.Path]::GetTempFileName()
    Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
    New-Item -Path $tempPath -ItemType Directory -Force | Out-Null
    $archiveFilePath = Join-Path -Path $tempPath -ChildPath 'package.zip'
    $expandPath = Join-Path -Path $tempPath -ChildPath '_expand'

    # download package
    $downloadUrl = "https://www.nuget.org/api/v2/package/TFSBuildScripts/$Version"
    Invoke-WebRequest -Uri $downloadUrl -Method Get -OutFile $archiveFilePath

    # extract package
    Expand-Archive -Path $archiveFilePath -DestinationPath $expandPath -Force

    # update nuspec (version & files)
    $nuspecFilePath = Join-Path -Path $expandPath -ChildPath 'TFSBuildScripts.nuspec'
    [xml]$nuspec = Get-Content -Path $nuspecFilePath
    $nuspec.package.metadata.version = $ReleaseVersion
    $files = $nuspec.CreateElement(“files”)
    $files.InnerXml = '<file src="tools\**\*.*" target="tools" /><file src="scripts\**\*.*" target="scripts" />'
    $nuspec.package.AppendChild($files) | Out-Null
    $nuspec.Save($nuspecFilePath)

    # create release-package
    Push-Location $expandPath
    Invoke-Expression "$nugetFilePath pack '$nuspecFilePath' -NoPackageAnalysis"
    Pop-Location

    # publish release-package
    $nupkgFilePath = (Get-ChildItem -Path $expandPath -Filter '*.nupkg').FullName
    Invoke-Expression "$nugetFilePath push '$nupkgFilePath' $ApiKey -Source https://www.nuget.org/api/v2/package"
}
finally {
    if (Test-Path -Path $tempPath -PathType Container) {
        Remove-Item -Path $tempPath -Recurse -Force
    }
}
