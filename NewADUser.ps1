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
$FirstName=$Name.split(' ')[0]
$Surname=$Name.split(' ')[1]

# Concat SamAccountName + UserPrincipalName
$SamAccountName=$FirstName.Substring(0,1).ToLower() + '.' + $Surname.ToLower()

$UserPrincipalName=$SamAccountName + '@' + $Domain

# Split $Domain 
$DomainName = $Domain.split('.')[0]
$TopLevelDomain = $Domain.split('.')[1]

# Build Path, input needs to match Child,Parent,Root structure
$path = ''
foreach ($Unit in $OU){
	$path += 'OU=' + $Unit + ','
}

$path += 'DC=' + $DomainName + ',' + 'DC=' + $TopLevelDomain

# Create the user
New-ADUser -Name $Name `
-GivenName $FirstName `
-Surname $Surname `
-SamAccountName $SamAccountName `
-UserPrincipalName $UserPrincipalName `
-Path $Path `
-AccountPassword (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force) `
-ChangePasswordAtNextLogon $true `
-Enabled $true

# Add user to groups
if ($Groups){
	foreach ($Group in $Groups) {
		Add-ADGroupMember -Identity $Group -Members $SamAccountName
	}
}