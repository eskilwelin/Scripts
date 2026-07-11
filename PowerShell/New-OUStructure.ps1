<#
.\New-OUStructure.ps1 -Root "domain.local"
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[Parameter(Mandatory=$true)]
	[string]$Root
)
Import-Module ActiveDirectory

$RootSplit = $Root -split '\.'
$DCParts = $RootSplit | ForEach-Object { "DC=$_"}
$Domain = $DCParts -join ','


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

    foreach ($Node in $Nodes){
        if ($Node -is [string]){
            $Node = @{Name = $Node}
        }
        $DN = "OU=$($Node.Name),$ParentDN"
        
        if (Get-ADOrganizationalUnit -Filter "distinguishedName -eq '$DN'"){
            Write-Error "Failed to create OU, $DN already exists."
        }
        else{
            if ($PSCmdlet.ShouldProcess($DN, "Creating OU")){
                New-ADOrganizationalUnit -Name $Node.Name -Path $ParentDN -ProtectedFromAccidentalDeletion $true
            }
        }
        
        New-Ou -Nodes $Node.Children -ParentDN $DN
    }   
}


try{
    New-OU -Nodes $OrganizationalUnits -ParentDN $Domain
}
catch{
    Write-Error "Error: $_"
}
