<#
Script out of date, need to update it with the new logic changes to the Lab version

.EXAMPLE
.\Import-ADUsers.ps1 -Import .\users.json -Domain nordvik.local
#>

[CmdletBinding(SupportsShouldProcess=$true)]

param(
	[Parameter(Mandatory=$true)][string]$Import,
	[Parameter(Mandatory=$true)][string]$Domain	
)

Import-Module ActiveDirectory

$ADUsers = Get-Content -Raw $Import | ConvertFrom-Json

function Get-ValidSam ($FirstName, $LastName) {
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

function Get-UPN ($Sam) {
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

foreach ($User in $ADUsers) {
	try {
		$SplitName = $User.name -split ' '
		$GivenName = $SplitName[0]
		$Surname = $SplitName[-1]

		$SamAccountName = Get-ValidSam -FirstName $GivenName -LastName $Surname

		$PlainPassword = New-RandomPassword -Length 12
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
		}
		if ($User.eployeeID -and (Get-ADUser -Filter "employeeID -eq '$($User.employeeID)'")) {
			Write-Host "A user with uid $($User.employeeID) already exists in $Domain" -ForegroundColor Yellow
			continue
		}
		if ($PSCmdlet.ShouldProcess($user.name, "Creating AD user")) {
			New-ADUser @UserInfo
			[pscustomobject]@{ User = $SamAccountName; Password = $plain }
			Write-Host "The user $SamAccountName was created." -ForegroundColor Green
		}
		}
	catch {
		Write-Host "Failed to create user $SamAccountName - $_" -ForegroundColor Red
	}
}