<#
.SYNOPSIS
    Builds the AD OU tree under a given top level OU and domain root.
.PARAMETER Root
    Domain in dotted form, e.g. corp.nordvik.se. Converted to DC= parts internally.
.PARAMETER OrgName
    Organization Name used to derive the top level OU.
.EXAMPLE
    .\New-OUStructure.ps1 -Root "corp.nordvik.se" -OrgName "Nordvik" -WhatIf
#>

# -WhatIf gets inherited by child scopes, the "New-OU" function
[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[Parameter(Mandatory=$true)][string]$Root,
    [Parameter(Mandatory=$true)][string]$OrgName
)

Import-Module ActiveDirectory

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

$BaseOU, $Domain = (Get-OU -DomainRoot $Root -OrgName $OrgName)

if (!(Get-ADOrganizationalUnit -Filter "distinguishedName -eq '$BaseOU'")){
    if ($PSCmdlet.ShouldProcess($BaseOU, "Creating OU")){
        New-ADOrganizationalUnit -Name $OrgName -Path $Domain -ProtectedFromAccidentalDeletion $true
    }
}

$OrganizationalUnits = @(
    @{Name = "Servers";  Children = @("DomainControllers", "MemberServers")}
    @{Name = "Workstations";  Children = @()}
    @{Name = "Users";  Children = @("Management", @{ Name = "IT"; Children = @("Admins") }, "Consulting", "Finance", "HR")}
    @{Name = "Disabled"; Children = @()}
    @{Name = "Groups"; Children = @("Security", "Distribution")}
)


function New-OU {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param($Nodes, $ParentDN)

    # Gives the children the "Name" key for the recursive function calls
    foreach ($Node in $Nodes){
        if ($Node -is [string]){
            $Node = @{Name = $Node}
        }
        $DN = "OU=$($Node.Name),$ParentDN"
        
        if (Get-ADOrganizationalUnit -Filter "distinguishedName -eq '$DN'"){
            Write-Verbose "OU already exists, skipping: $DN."
        }
        else {
            if ($PSCmdlet.ShouldProcess($DN, "Creating OU")){
                New-ADOrganizationalUnit -Name $Node.Name -Path $ParentDN -ProtectedFromAccidentalDeletion $true
                Write-Verbose "The OU $($Node.Name) was created."
            }
        }
        
        New-Ou -Nodes $Node.Children -ParentDN $DN
    }   
}

try{
    New-OU -Nodes $OrganizationalUnits -ParentDN $BaseOU
}
catch{
    Write-Error "$($_.Exception.Message)"
}
