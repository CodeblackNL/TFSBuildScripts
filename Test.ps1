$scriptPath = $PSScriptRoot

# determine if current user is administrator
$identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
$isAdmin = $principal.IsInRole( [System.Security.Principal.WindowsBuiltInRole]::Administrator )

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

# install Pester if it is missing
$pesterVersion = "3.1.1"
cinst pester -version $pesterVersion
# determine the Pester installation folder
$pesterDir = "$chocoDir\lib\Pester.$pesterVersion"

# run the tests, by executing Pester
# Import-Module C:\ProgramData\chocolatey\lib\pester.3.1.1\tools\Pester.psm1
if(-not $isAdmin){
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName="$env:windir\System32\WindowsPowerShell\v1.0\powershell.exe"
    $psi.Verb="runas"
    $psi.Arguments="-NoProfile -ExecutionPolicy unrestricted -Command `". { CD '$scriptPath';. '$pesterDir\tools\bin\pester.bat'; `$ec = `$?;if(!`$ec){Write-Host 'Press any key to continue ...';`$host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');exit 1} } `""
    $s = [System.Diagnostics.Process]::Start($psi)
    $s.WaitForExit()
    exit $s.ExitCode
} else {
    . "$pesterDir\tools\bin\pester.bat"
}