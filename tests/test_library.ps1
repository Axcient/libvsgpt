# Tests library functions and types.
#
# Version: 20200216

$ExitSuccess = 0
$ExitFailure = 1
$ExitIgnore = 77

$LibraryTests = "boot_record chs_address error io_handle mbr_partition_entry mbr_partition_type notify partition partition_entry partition_table_header partition_values section_values sector_data"
$LibraryTestsWithInput = "support volume"

$InputGlob = "*"

Function GetTestProfileDirectory
{
	param( [string]$TestInputDirectory, [string]$TestProfile )

	$TestProfileDirectory = "${TestInputDirectory}\.${TestProfile}"

	If (-Not (Test-Path -Path ${TestProfileDirectory} -PathType "Container"))
	{
		New-Item -ItemType "directory" -Path ${TestProfileDirectory}
	}
	Return ${TestProfileDirectory}
}

Function GetTestSetDirectory
{
	param( [string]$TestProfileDirectory, [string]$TestSetInputDirectory )

	$TestSetDirectory = "${TestProfileDirectory}\${TestSetInputDirectory.Basename}"

	If (-Not (Test-Path -Path ${TestSetDirectory} -PathType "Container"))
	{
		New-Item -ItemType "directory" -Path ${TestSetDirectory}
	}
	Return ${TestSetDirectory}
}

Function GetTestExecutablesDirectory
{
	$TestExecutablesDirectory = ""

	ForEach (${VSDirectory} in "msvscpp vs2008 vs2010 vs2012 vs2013 vs2015 vs2017 vs2019" -split " ")
	{
		ForEach (${VSConfiguration} in "Release VSDebug" -split " ")
		{
			ForEach (${VSPlatform} in "Win32 x64" -split " ")
			{
				$TestExecutablesDirectory = "..\${VSDirectory}\${VSConfiguration}\${VSPlatform}"

				If (Test-Path ${TestExecutablesDirectory})
				{
					Return ${TestExecutablesDirectory}
				}
			}
			$TestExecutablesDirectory = "..\${VSDirectory}\${VSConfiguration}"

			If (Test-Path ${TestExecutablesDirectory})
			{
				Return ${TestExecutablesDirectory}
			}
		}
	}
	Return ${TestExecutablesDirectory}
}

Function ReadIgnoreList
{
	param( [string]$TestProfileDirectory )

	$IgnoreFile = "${TestProfileDirectory}\ignore"
	$IgnoreList = ""

	If (Test-Path -Path ${IgnoreFile} -PathType "Leaf")
	{
		$IgnoreList = Get-Content -Path ${IgnoreFile} | Where {$_ -notmatch '^#.*'}
	}
	Return $IgnoreList
}

Function RunTest
{
	param( [string]$TestType )

	$TestDescription = "Testing: ${TestName}"
	$TestExecutable = "${TestExecutablesDirectory}\vsgpt_test_${TestName}.exe"

	$Output = Invoke-Expression ${TestExecutable}
	$Result = ${LastExitCode}

	If (${Result} -ne ${ExitSuccess})
	{
		Write-Host ${Output} -foreground Red
	}
	Write-Host "${TestDescription} " -nonewline

	If (${Result} -ne ${ExitSuccess})
	{
		Write-Host " (FAIL)"
	}
	Else
	{
		Write-Host " (PASS)"
	}
	Return ${Result}
}

Function RunTestWithInput
{
	param( [string]$TestType )

	$TestDescription = "Testing: ${TestName}"
	$TestExecutable = "${TestExecutablesDirectory}\vsgpt_test_${TestName}.exe"

	$TestProfileDirectory = GetTestProfileDirectory "input" "libvsgpt"

	$IgnoreList = ReadIgnoreList ${TestProfileDirectory}

	$Result = ${ExitSuccess}

	ForEach ($TestSetInputDirectory in Get-ChildItem -Path "input" -Exclude ".*")
	{
		If (-Not (Test-Path -Path ${TestSetInputDirectory} -PathType "Container"))
		{
			Continue
		}
		If (${TestSetInputDirectory} -Contains ${IgnoreList})
		{
			Continue
		}
		$TestSetDirectory = GetTestSetDirectory ${TestProfileDirectory} ${TestSetInputDirectory}

		If (Test-Path -Path "${TestSetDirectory}\files" -PathType "Leaf")
		{
			$InputFiles = Get-Content -Path "${TestSetDirectory}\files" | Where {$_ -ne ""}
		}
		Else
		{
			$InputFiles = Get-ChildItem -Path ${TestSetInputDirectory} -Include ${InputGlob}
		}
		ForEach ($InputFile in ${InputFiles})
		{
			# TODO: add test option support
			$Output = Invoke-Expression ${TestExecutable}
			$Result = ${LastExitCode}

			If (${Result} -ne ${ExitSuccess})
			{
				Break
			}
		}
		If (${Result} -ne ${ExitSuccess})
		{
			Break
		}
	}
	If (${Result} -ne ${ExitSuccess})
	{
		Write-Host ${Output} -foreground Red
	}
	Write-Host "${TestDescription} " -nonewline

	If (${Result} -ne ${ExitSuccess})
	{
		Write-Host " (FAIL)"
	}
	Else
	{
		Write-Host " (PASS)"
	}
	Return ${Result}
}

$TestExecutablesDirectory = GetTestExecutablesDirectory

If (-Not (Test-Path ${TestExecutablesDirectory}))
{
	Write-Host "Missing test executables directory." -foreground Red

	Exit ${ExitFailure}
}

$Result = ${ExitIgnore}

Foreach (${TestName} in ${LibraryTests} -split " ")
{
	# Split will return an array of a single empty string when LibraryTests is empty.
	If (-Not (${TestName}))
	{
		Continue
	}
	$Result = RunTest ${TestName}

	If (${Result} -ne ${ExitSuccess})
	{
		Break
	}
}

Foreach (${TestName} in ${LibraryTestsWithInput} -split " ")
{
	# Split will return an array of a single empty string when LibraryTestsWithInput is empty.
	If (-Not (${TestName}))
	{
		Continue
	}
	If (Test-Path -Path "input" -PathType "Container")
	{
		$Result = RunTestWithInput ${TestName}
	}
	Else
	{
		$Result = RunTest ${TestName}
	}
	If (${Result} -ne ${ExitSuccess})
	{
		Break
	}
}

Exit ${Result}

