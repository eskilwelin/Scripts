<#
.EXAMPLE
.\Import-ADUsersLab.ps1 -Path .\users.json -Domain nordvik.local
#>

[CmdletBinding(SupportsShouldProcess=$true)]

param(
	[Parameter(Mandatory=$true)][string]$Path,
	[Parameter(Mandatory=$true)][string]$Domain	
)

Import-Module ActiveDirectory

$ADUsers = Get-Content -Raw $Path | ConvertFrom-Json

function Get-ValidSam ($FirstName, $LastName) {
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

function Get-UPN ($Sam) {
	return $Sam + '@' + $Domain
}


foreach ($User in $ADUsers) {
	try {
		$SplitName = $User.name -split ' '
		$GivenName = $SplitName[0]
		$Surname = $SplitName[-1]

		$SamAccountName = Get-ValidSam -FirstName $GivenName -LastName $Surname

		$PlainPassword = "Password123!"
		
		$UserInfo = @{
			Name = $User.name
			GivenName = $GivenName
			Surname = $Surname
			SamAccountName = $SamAccountName
			UserPrincipalName = Get-UPN -Sam $SamAccountName
			employeeID = $User.employeeID
			ChangePasswordAtLogon = $false
			Enabled = $true
			EmailAddress = Get-UPN -Sam $SamAccountName
			Title = $User.title
			Department = $User.department
			AccountPassword = (ConvertTo-SecureString $PlainPassword -AsPlainText -Force)
		}
		if ($User.eployeeID -and (Get-ADUser -Filter "employeeID -eq '$($User.employeeID)'")) {
			Write-Host "A user with uid $($User.employeeID) already exists in $Domain" -ForegroundColor Yellow
			continue
		}
		if ($PSCmdlet.ShouldProcess($user.name, "Creating AD user")) {
			New-ADUser @UserInfo
			Write-Host "The user $SamAccountName was created." -ForegroundColor Green
		} 
		}
	catch {
		Write-Host "Failed to populate information for user $SamAccountName - $_" -ForegroundColor Red
	}
}