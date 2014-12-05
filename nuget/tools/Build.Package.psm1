##-----------------------------------------------------------------------
## <copyright file="Build.Package.psm1">(c) https://github.com/CodeblackNL/TFSBuildScripts. See https://github.com/CodeblackNL/TFSBuildScripts/blob/master/LICENSE. </copyright>
##-----------------------------------------------------------------------
<#
.SYNOPSIS
    Module containing functions for the TFSBuildScripts NuGet-package.
.DESCRIPTION
    Module containing functions for the TFSBuildScripts NuGet-package.

    Author: Jeroen Swart
    Versions:
    - 1.0.0  03-12-2014  Initial version; includes Add-BuildScripts
#>

function Add-BuildScripts {
<#
    .SYNOPSIS
        Adds the build-scripts to a solution.
    .DESCRIPTION
        Adds the build-scripts to a solution.
		If the FolderName parameter is not provided, the default folder-name 'BuildScripts' is used.
		If the solution-folder already exists, no changes are made. In this case, specify a different FolderName or
		use the Force parameter to add the build-scripts to the existing folder.
		Use the Overwrite parameter to overwrite any existing build-scripts with the original build-scripts from the package.

		Author: Jeroen Swart
		Versions:
		- 1.0.0  11-11-2014  Initial version

    .PARAMETER  FolderName
        Defines the name of the solution-folder to which the build-scripts are added.
    .PARAMETER  Force
        Specifies that build-scripts should be added, even if the solution-folder already exists.
    .PARAMETER  Overwrite
        Specifies that existing build-scripts should be overwritten.
#>
    param (
        [Parameter(Mandatory = $false)]
        [string]$FolderName = "BuildScripts",
        [Parameter(Mandatory = $false)]
        [switch]$Force,
        [Parameter(Mandatory = $false)]
        [switch]$Overwrite
    )

    if ($Overwrite) {
        $Force = $true
        $with = " with 'Overwrite'"
    }
    elseif ($Force) {
        $with = " with 'Force'"
    }

    Write-Host "Adding build-scripts to solution-folder '$FolderName'$with."

    $kindSolutionFolder = "{66A26720-8FB5-11D2-AA7E-00C04F688DDE}"
    $scriptFiles = "Build.psm1","PreBuild.ps1","PostBuild.ps1"

    $solution = Get-Interface $dte.Solution ([EnvDTE80.Solution2])

    $toolsPath = $PSScriptRoot
    $solutionPath = Split-Path $solution.FullName
    $folderPath = Join-Path $solutionPath $FolderName

    $solutionFolder = $solution.Projects | Where { $_.Kind -eq $kindSolutionFolder -and $_.ProjectName -eq $FolderName }

    if ($solutionFolder -and -not $Force) {
        Write-Host "Solution-folder '$FolderName' already exists, no actions taken."
        Write-Host "Use 'Add-BuildScripts -FolderName [folder-name]' to specify a different solution-folder, or"
        Write-Host "use 'Add-BuildScripts -Force' to add the build-scripts to the existing solution-folder."

        return
    }

    if (-not $solutionFolder) {
        $solutionFolder = $solution.AddSolutionFolder($FolderName)

        Write-Host "Added solution-folder '$FolderName'."
    }
    else {
        Write-Host "Found existing solution-folder '$FolderName'."
    }

    if (-not (Test-Path $folderPath)) {
        New-Item -Path $folderPath -ItemType Container | Out-Null

        Write-Host "Added folder '$folderPath'."
    }

    $projectItems = Get-Interface $solutionFolder.ProjectItems ([EnvDTE.ProjectItems])
    $fileCount = 0
    foreach ($scriptFile in $scriptFiles) {
        $projectItem = $projectItems.GetEnumerator() | Where { $_.Name -eq $scriptFile }
        if (-not $projectItem -or $Overwrite) {
            $sourcePath = Join-Path $toolsPath $scriptFile
            $scriptPath = Join-Path $folderPath $scriptFile
            $fileExists = Test-Path $scriptPath

            if (-not $fileExists -or $Overwrite) {
                Copy-Item $sourcePath $scriptPath -Force | Out-Null
            }

            if (-not $projectItem) {
                $projectItems.AddFromFile($scriptPath) | Out-Null
            }

            if (-not $projectItem -or -not $fileExists) {
                Write-Host "Added file '$scriptFile' to folder '$folderPath'."
            }
            else {
                Write-Host "Replaced file '$scriptFile' in folder '$folderPath'."
            }

            $fileCount++
        }
    }

    if (-not $fileCount) {
        Write-Host "No file added or replaced."
    }
}
