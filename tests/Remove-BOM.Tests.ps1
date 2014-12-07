##-----------------------------------------------------------------------
## <copyright file="Remove-BOM.Tests.ps1">(c) https://github.com/CodeblackNL/TFSBuildScripts. See https://github.com/CodeblackNL/TFSBuildScripts/blob/master/LICENSE. </copyright>
##-----------------------------------------------------------------------

Remove-Module "Build" -ErrorAction SilentlyContinue
Import-Module "$PSScriptRoot\..\src\Build.psm1"

$BOM_UTF8_1 = 0xef
$BOM_UTF8_2 = 0xbb
$BOM_UTF8_3 = 0xbf

function Write-File {
	param (
		[string]$Path,
		[string]$Value,
		[switch]$ReadOnly
	)

	#$fullPath = (Get-Item (Split-Path $Path)).FullName

	#$Utf8BomEncoding = New-Object System.Text.UTF8Encoding($true)
	#[System.IO.File]::WriteAllLines($fullPath, $Value, $Utf8BomEncoding)	
	#Set-Content -Path $Path -Value $Value
	$Value | Out-File -Encoding "UTF8" $Path

	if ($ReadOnly) {
		Set-ItemProperty $Path -name IsReadOnly -value $true
	}
}

Describe "Remove-BOM" {
    Context "when no search-pattern is provided" {
        It "should remove the BOM from cs & vb files" {
            # add cs & vb file with BOM, and readonly-attribute
			Write-File -Path "TestDrive:\file.cs" -Value "Test file" -ReadOnly
	        Write-File -Path "TestDrive:\file.vb" -Value "Test file" -ReadOnly

			Remove-BOM -Directory "TestDrive:\"

            # check both files have the BOM removed
			foreach ($file in Get-ChildItem "TestDrive:\") {
				$bytes = Get-Content $file.FullName -Encoding Byte -TotalCount 4
				$bytes[0] | Should Not Be $BOM_UTF8_1
				$bytes[1] | Should Not Be $BOM_UTF8_2
				$bytes[2] | Should Not Be $BOM_UTF8_3
			}
		}
	}

    Context "when no search-pattern is provided with files in sub-folder" {
        It "should remove the BOM from cs & vb files" {
            # add cs & vb file, in sub-folder, with BOM, and readonly-attribute
			New-Item -Path "TestDrive:\test\" -ItemType Container
			Write-File -Path "TestDrive:\test\file.cs" -Value "Test file" -ReadOnly
	        Write-File -Path "TestDrive:\test\file.vb" -Value "Test file" -ReadOnly

			Remove-BOM -Directory "TestDrive:\"

            # check both files have the BOM removed
			foreach ($file in Get-ChildItem "TestDrive:\test") {
				$bytes = Get-Content $file.FullName -Encoding Byte -TotalCount 4
				$bytes[0] | Should Not Be $BOM_UTF8_1
				$bytes[1] | Should Not Be $BOM_UTF8_2
				$bytes[2] | Should Not Be $BOM_UTF8_3
			}
        }
    }

    Context "when a search-pattern is provided" {
        It "should remove the BOM from files acording to search-pattern" {
            # add cs & vb file with BOM, and readonly-attribute
			Write-File -Path "TestDrive:\file.cs" -Value "Test file" -ReadOnly
	        Write-File -Path "TestDrive:\file.vb" -Value "Test file" -ReadOnly

			Remove-BOM -Directory "TestDrive:\" -SearchPattern "*.cs"

            # check included file has the BOM removed
			$bytes = Get-Content "TestDrive:\file.cs" -Encoding Byte -TotalCount 4
			$bytes[0] | Should Not Be $BOM_UTF8_1
			$bytes[1] | Should Not Be $BOM_UTF8_2
			$bytes[2] | Should Not Be $BOM_UTF8_3

            # check not included file doesn't have the BOM removed
			$bytes = Get-Content "TestDrive:\file.vb" -Encoding Byte -TotalCount 4
			$bytes[0] | Should Be $BOM_UTF8_1
			$bytes[1] | Should Be $BOM_UTF8_2
			$bytes[2] | Should Be $BOM_UTF8_3
		}
}

    Context "when a search-pattern is provided with files in sub-folder" {
        It "should remove the BOM from files acording to search-pattern" {
            # add cs & vb file, in sub-folder, with BOM, and readonly-attribute
			New-Item -Path "TestDrive:\test\" -ItemType Container
			Write-File -Path "TestDrive:\test\file.cs" -Value "Test file" -ReadOnly
	        Write-File -Path "TestDrive:\test\file.vb" -Value "Test file" -ReadOnly

			Remove-BOM -Directory "TestDrive:\" -SearchPattern "*.cs"

            # check included file has the BOM removed
			$bytes = Get-Content "TestDrive:\test\file.cs" -Encoding Byte -TotalCount 4
			$bytes[0] | Should Not Be $BOM_UTF8_1
			$bytes[1] | Should Not Be $BOM_UTF8_2
			$bytes[2] | Should Not Be $BOM_UTF8_3

            # check not included file doesn't have the BOM removed
			$bytes = Get-Content "TestDrive:\test\file.vb" -Encoding Byte -TotalCount 4
			$bytes[0] | Should Be $BOM_UTF8_1
			$bytes[1] | Should Be $BOM_UTF8_2
			$bytes[2] | Should Be $BOM_UTF8_3
        }
    }
}
