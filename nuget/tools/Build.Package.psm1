##-----------------------------------------------------------------------
## <copyright file="Build.Package.psm1">(c) https://github.com/CodeblackNL/TFSBuildScripts. See https://github.com/CodeblackNL/TFSBuildScripts/blob/master/LICENSE.</copyright>
##-----------------------------------------------------------------------
<#
.SYNOPSIS
    Module containing functions for the TFSBuildScripts NuGet-package.
.DESCRIPTION
    Module containing functions for the TFSBuildScripts NuGet-package.
#>

function Add-BuildScripts {
<#
    .SYNOPSIS
        Adds the build-scripts to a solution.
    .DESCRIPTION
        Adds the build-scripts to a solution.
		If the FolderName parameter is not provided, the default folder-name '_BuildScripts' is used.
		If the solution-folder already exists, no changes are made. In this case, specify a different FolderName or
		use the Force parameter to add the build-scripts to the existing folder.
		Use the Overwrite parameter to overwrite any existing build-scripts with the original build-scripts from the package.

		Author: Jeroen Swart
		Versions:
		- 1.0.0  11-11-2014  Initial version
		- 2.0.0  12-03-2017  Updated for new scripts and changed the default folder-name from 'BuildScripts' to '_BuildScripts'

    .PARAMETER  FolderName
        Defines the name of the solution-folder to which the build-scripts are added. Default is '_BuildScripts'.
    .PARAMETER  Force
        Specifies that build-scripts should be added, even if the solution-folder already exists.
    .PARAMETER  Overwrite
        Specifies that existing build-scripts should be overwritten.
#>
    param (
        [Parameter(Mandatory = $false)]
        [string]$FolderName = '_BuildScripts',
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

    $kindSolutionFolder = '{66A26720-8FB5-11D2-AA7E-00C04F688DDE}'

    $solution = Get-Interface $dte.Solution ([EnvDTE80.Solution2])
    $solutionPath = Split-Path -Path $solution.FullName -Parent
    $folderPath = Join-Path -Path $solutionPath -ChildPath $FolderName

    $solutionFolder = $solution.Projects | Where-Object { $_.Kind -eq $kindSolutionFolder -and $_.ProjectName -eq $FolderName }
    if ($solutionFolder -and -not $Force) {
        Write-Host "Solution-folder '$FolderName' already exists, no actions taken."
        Write-Host "Use 'Add-BuildScripts -FolderName [folder-name]' to specify a different solution-folder, or"
        Write-Host "use 'Add-BuildScripts -Force' to add the build-scripts to the existing solution-folder, or"
        Write-Host "use 'Add-BuildScripts -Overwrite' to overwrite existing build-scripts."

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

    $scriptFiles = Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath '..\scripts')

    $fileCount = 0
    foreach ($scriptFile in $scriptFiles) {
        $projectItem = $projectItems.GetEnumerator() | Where-Object { $_.Name -eq $scriptFile.Name }
        if (-not $projectItem -or $Overwrite) {
            $destinationFileName = $scriptFile.Name
            $destinationFilePath = Join-Path -Path $folderPath -ChildPath $destinationFileName
            $fileExists = Test-Path -Path $destinationFilePath

            if (-not $fileExists -or $Overwrite) {
                Copy-Item -Path $scriptFile.FullName -Destination $destinationFilePath -Force | Out-Null
            }

            if (-not $projectItem) {
                $projectItems.AddFromFile($destinationFilePath) | Out-Null
            }

            if (-not $projectItem -or -not $fileExists) {
                Write-Host "Added file '$destinationFileName' to folder '$folderPath'."
            }
            else {
                Write-Host "Replaced file '$destinationFileName' in folder '$folderPath'."
            }

            $fileCount++
        }
    }

    if (-not $fileCount) {
        Write-Host "No file added or replaced."
    }
}
