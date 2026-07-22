<#
.SYNOPSIS
    Imports and creates users from a JSON file into an OU derived from the "department" field.
    Assigns group memberships to users — also applies to existing users on re-run, 
	so membership changes in the JSON take effect without needing a full user recreation.
.PARAMETER Import
    Path to the JSON file containing user information.
.PARAMETER Root
    Domain in dotted form, e.g. corp.nordvik.se. Converted to DC= parts internally.
.PARAMETER OrgName
    Organization name, needed for the top-level OU structure.
.EXAMPLE
    .\Import-ADUsersLab.ps1 -Import .\users.json -Root "nordvik.local" -OrgName "Nordvik" -WhatIf
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[Parameter(Mandatory=$true)][string]$Import,
	[Parameter(Mandatory=$true)][string]$Root,
	[Parameter(Mandatory=$true)][string]$OrgName	
)

Import-Module ActiveDirectory

$ADUsers = (Get-Content -Raw $Import | ConvertFrom-Json)

function Get-OU{
	param(
		[Parameter(Mandatory=$true)][string]$Root,
		[Parameter(Mandatory=$true)][string]$OrgName
	)
	$RootSplit = $Root -split '\.'
	$DCParts = $RootSplit | ForEach-Object { "DC=$_"}
	$Domain = $DCParts -join ','

	$BaseOU = "OU=$OrgName,$Domain"
	return $BaseOU, $Domain
}

$BaseOU, $Domain = (Get-OU -Root $Root -OrgName $OrgName)

function Get-ValidSam {
	param(
		[Parameter(Mandatory=$true)][string]$FirstName,
		[Parameter(Mandatory=$true)][string]$LastName
	)
	$Base = ($FirstName.Substring(0,1) + '.' + $LastName).ToLower()
	if ($Base.length -gt 17) {$Base = $Base.Substring(0,17)}
		
	$Increment = 1
    $Sam = $Base
	while (Get-ADUser -Filter "SamAccountName -eq '$Sam'") {
        $Sam = $Base + $Increment
		$Increment ++
	}
	return $Sam
}

function Get-UPN {
	param([Parameter(Mandatory=$true)][string]$Sam)
	return $Sam + '@' + $Domain
}

function New-RandomPassword {
    param([int]$Length = 16)

    $sets = @{
        Upper  = 'ABCDEFGHJKLMNPQRSTUVWXYZ'   # no I/O/1/0 to avoid confusion
        Lower  = 'abcdefghijkmnpqrstuvwxyz'
        Digit  = '23456789'
        Symbol = '!@#$%^&*-_=+'
    }
    $all = -join $sets.Values
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()

    function Get-Index ([int]$max) {
        $b = [byte[]]::new(4); $rng.GetBytes($b)
        [int]([BitConverter]::ToUInt32($b,0) % $max)
    }

    # one guaranteed char per class, so AD complexity policy always passes
    $chars = foreach ($s in $sets.Values) { $s[(Get-Index $s.Length)] }
    for ($i = $chars.Count; $i -lt $Length; $i++) { $chars += $all[(Get-Index $all.Length)] }
    $rng.Dispose()

    -join ($chars | Sort-Object { Get-Index 1000000 })   # shuffle the guaranteed chars off the front
}

function Get-Path {
	param([Parameter(Mandatory=$true)][string]$Department)

	$Path = (Get-ADOrganizationalUnit -Filter "Name -Like '$Department'" -SearchBase "$BaseOU" | Select-Object -ExpandProperty DistinguishedName)
	if (@($Path).Count -eq 0){
		throw "Department '$Department' has 0 matching OUs"
	}
	elseif (@($Path).Count -gt 1){
		throw "Department '$Department' has more than 1 matching OUs"
	}
	else{
		return $Path
	}
}


foreach ($User in $ADUsers) {
	try {
		$SplitName = $User.name -split ' '
		$GivenName = $SplitName[0]
		$Surname = $SplitName[-1]

		$SamAccountName = (Get-ValidSam -FirstName $GivenName -LastName $Surname)

		$PlainPassword = (New-RandomPassword -Length 12)
		$SecurePassword = (ConvertTo-SecureString $PlainPassword -AsPlainText -Force)
		
		$UserInfo = @{
			Name = $User.name
			GivenName = $GivenName
			Surname = $Surname
			SamAccountName = $SamAccountName
			UserPrincipalName = Get-UPN -Sam $SamAccountName
			employeeID = $User.employeeID
			ChangePasswordAtLogon = $true
			Enabled = $true
			EmailAddress = Get-UPN -Sam $SamAccountName
			Title = $User.title
			Department = $User.department
			AccountPassword = $SecurePassword
			Path = (Get-Path -Department $User.department)
		}
		if ($User.employeeID -and ($ExistingUser = Get-ADUser -Filter "employeeID -eq '$($User.employeeID)'")) {
			$SamAccountName = $ExistingUser.SamAccountName
			Write-Verbose "A user with uid $($User.employeeID) already exists in $Domain"
		}
		else {
			if ($PSCmdlet.ShouldProcess($User.name, "Creating AD user")) {
				New-ADUser @UserInfo
				[pscustomobject]@{ User = $SamAccountName; Password = $plain }
				Write-Verbose "The user $SamAccountName was created."
			} 
		}
		if ($User.groups){
			foreach ($Group in $User.groups){
				if ($PSCmdlet.ShouldProcess($Group, "Adding $SamAccountName to group")){
					Add-ADGroupMember -Identity $Group -Members $SamAccountName
					Write-Verbose "Adding $SamAccountName to $Group"
				}
			}
		}
		}
	catch {
		Write-Verbose "Failed to populate information for user $SamAccountName - $($_.Exception.Message)"
	}
}