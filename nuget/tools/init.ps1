##-----------------------------------------------------------------------
## <copyright file="init.ps1">(c) https://github.com/CodeblackNL/TFSBuildScripts. See https://github.com/CodeblackNL/TFSBuildScripts/blob/master/LICENSE. </copyright>
##-----------------------------------------------------------------------
<#
.SYNOPSIS
    NuGet-package initialization script.
.DESCRIPTION
    NuGet-package initialization script, which is executed during installation of the package.
	The 'Build.Package.psm1' module is imported to make the 'Add-BuildScripts' function available.
	Then calls 'Add-BuildScripts', without force or overwrite, to add the build-scripts to the solution.

    Author: Jeroen Swart
    Versions:
    - 1.0.0  03-12-2014  Initial version

.PARAMETER  $installPath
    Specifies the path to the folder where the package is installed.
.PARAMETER  $toolsPath
	Specifies the path to the tools directory in the folder where the package is installed.
.PARAMETER  $package
	A reference to the package object.
.PARAMETER  $project
	A reference to the EnvDTE project object and represents the project the package is installed into.
	Note: Since this is a solution-level package, this parameter will always be null.
#>

param($installPath, $toolsPath, $package, $project)

Import-Module (Join-Path $toolsPath Build.Package.psm1)

Add-BuildScripts
