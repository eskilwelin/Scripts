[CmdletBinding(SupportsShouldProcess=$true)]

param(
	[Parameter(Mandatory=$true)]
	[string]$Path,
	[Parameter(Mandatory=$true)]
	[string]$Domain	
)

Import-Module ActiveDirectory

$ADUsers = Get-Content -Raw $Path | ConvertFrom-Json

function Get-ValidSam ($Sam) {
	$IncrementSam = 1
    $NewSam = $Sam
	while ($true) {
        if (Get-ADUser -Filter "SamAccountName -eq '$NewSam'") {
            $NewSam = $Sam + $IncrementSam
	    }
        else {
			return $NewSam
        }
		$IncrementSam ++
    }
}

function Get-UPN ($Sam) {
	return $Sam + '@' + $Domain
}

foreach ($User in $ADUsers) {
	try {
		$SplitName = $User.name -split ' '
		$GivenName = $SplitName[0]
		$Surname = $SplitName[-1]

		# Validate Sam 
		$SamAccountName = $GivenName.Substring(0,1).ToLower() + '.' + $Surname.ToLower()
		$SamAccountName = Get-ValidSam -Sam $SamAccountName


		$Email = Get-UPN -Sam $SamAccountName
		$UPN = Get-UPN -Sam $SamAccountName
		
		$UserInfo = @{
			Name = $User.name
			GivenName = $GivenName
			Surname = $Surname
			SamAccountName = $SamAccountName
			UserPrincipalName = $UPN
			ChangePasswordAtNextLogon = $true
			Enabled = $true
			EmailAddress = $Email
			Title = $User.title
			Department = $User.department
			AccountPassword = (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force)
		}
		# Change this to check for UID
		if (Get-ADUser -Filter "SamAccountName -eq '$SamAccountName'") {
			Write-Host "A user with username $SamAccountName already exists in $Domain" -ForegroundColor Yellow
			continue
		}
		if ($PSCmdlet.ShouldProcess($user.name, "Creating AD user")) {
			New-ADUser @UserInfo
			Write-Host "The user $SamAccountName was created." -ForegroundColor Green
		}
		}
	catch {
		Write-Host "Failed to create user $SamAccountName - $_" -ForegroundColor Red
	}
}