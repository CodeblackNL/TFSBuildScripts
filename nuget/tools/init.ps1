param($installPath, $toolsPath, $package, $project)

Import-Module (Join-Path -Path $toolsPath -ChildPath 'Build.Package.psm1') -Force
Add-BuildScripts
