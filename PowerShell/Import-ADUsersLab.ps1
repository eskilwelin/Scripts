<#
.EXAMPLE
.\Import-ADUsersLab.ps1 -Import .\users.json -Root "nordvik.local" -OrgName "Nordvik"
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
	if ($Base.length -gt 18) {$Base = $Base.Substring(0,18)}
		
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

		$PlainPassword = "Password123!"
		
		$UserInfo = @{
			Name = $User.name
			GivenName = $GivenName
			Surname = $Surname
			SamAccountName = $SamAccountName
			UserPrincipalName = (Get-UPN -Sam $SamAccountName)
			employeeID = $User.employeeID
			ChangePasswordAtLogon = $false
			Enabled = $true
			EmailAddress = (Get-UPN -Sam $SamAccountName)
			Title = $User.title
			Department = $User.department
			AccountPassword = (ConvertTo-SecureString $PlainPassword -AsPlainText -Force)
			Path = (Get-Path($User.department))
		}

		if ($User.employeeID -and (Get-ADUser -Filter "employeeID -eq '$($User.employeeID)'")) {
			Write-Host "A user with uid $($User.employeeID) already exists in $Domain" -ForegroundColor Yellow
			continue
		}

		if ($PSCmdlet.ShouldProcess($user.name, "Creating AD user")) {
			New-ADUser @UserInfo
			Write-Host "The user $SamAccountName was created." -ForegroundColor Green
		} 

		}
	catch {
		Write-Host "Failed to populate information for user $SamAccountName - $($_.Exception.Message)" -ForegroundColor Red
	}
}