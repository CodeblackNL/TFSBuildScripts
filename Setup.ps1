##-----------------------------------------------------------------------
## <copyright file="Setup.ps1">(c) https://github.com/CodeblackNL/TFSBuildScripts. See https://github.com/CodeblackNL/TFSBuildScripts/blob/master/LICENSE. </copyright>
##-----------------------------------------------------------------------

# ensure chocolatey is installed
if(-not $env:ChocolateyInstall -or -not (Test-Path "$env:ChocolateyInstall")){
  iex ((new-object net.webclient).DownloadString("https://chocolatey.org/install.ps1"))
} else {
  Write-Host "Chocolatey Install located at $($env:ChocolateyInstall)"
}

# determine the chocolatey installation folder
$chocoDir = $env:ChocolateyInstall
if (!$chocoDir) {
    $chocoDir="$env:AllUsersProfile\chocolatey"
}
if (!(Test-Path($chocoDir))) {
    $chocoDir="$env:SystemDrive\chocolatey"
}
$chocoDir = $chocoDir.Replace("\bin","")

# ensure the chocolatey installation folder is in the path
$env:Path = $env:Path.Replace(";$chocoDir\bin;", "")
$env:Path += ";$chocoDir\bin;"
Write-Host "Path is $($env:Path)"

# install NuGet & Pester if they are missing
cinst nuget.commandline
cinst pester -version 3.1.1
