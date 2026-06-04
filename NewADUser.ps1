param(
	[Parameter(Mandatory=$true)]
	[string]$Name,
	[Parameter(Mandatory=$true)]
	[string]$Domain,
	[Parameter(Mandatory=$true)]
	[string[]]$OU,
	[Parameter(Mandatory=$false)]
	[string[]]$Groups
)

# Split $Name
$SplitName = $Name -split ' '
if ($SplitName.Count -lt 2) {
	throw "Name parameter has to contain a first name and a surname."
}

$FirstName = $SplitName[0]
$Surname = $SplitName[-1]

# Concat SamAccountName + UserPrincipalName
$SamAccountName = $FirstName.Substring(0,1).ToLower() + '.' + $Surname.ToLower()

$UserPrincipalName = $SamAccountName + '@' + $Domain

# Split $Domain 
$SplitDomain = $Domain -split '\.'

# Build Path, input needs to match Child,Parent,Root structure
$Path = ''
foreach ($Unit in $OU) {
	$path += 'OU=' + $Unit + ','
}

$DCParts = $SplitDomain | ForEach-Object { "DC=$_"}
$DCPath = $DCParts -join ','

$Path += $DCPath

<# 
# Password prmpt instead of the hard-coded password 
# Change the -AccountPassword in the New-ADUser command
$PasswordPrompt = Read-Host "Enter password for" $SamAccountName -AsSecureString
#>

try {
	# Create the user
	New-ADUser -Name $Name `
	-GivenName $FirstName `
	-Surname $Surname `
	-SamAccountName $SamAccountName `
	-UserPrincipalName $UserPrincipalName `
	-Path $Path `
	-AccountPassword (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force) `
	# -AccountPassword $PasswordPrompt `
	-ChangePasswordAtNextLogon $true `
	-Enabled $true
	
	# Add user to groups
	if ($Groups){
		foreach ($Group in $Groups) {
			Add-ADGroupMember -Identity $Group -Members $SamAccountName
		}
	}
}
catch {
    Write-Error "Failed to create user or add to groups: $_"
    exit 1
}