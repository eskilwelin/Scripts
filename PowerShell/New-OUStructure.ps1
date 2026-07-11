<#
.\New-OUStructure.ps1 -Root "domain.local"
#>

[CmdletBinding(SupportsShouldProcess=$true)]

param(
	[Parameter(Mandatory=$true)]
	[string]$Root
)

$RootSplit = $Root -split '\.'

$DCParts = $RootSplit | ForEach-Object { "DC=$_"}
$Domain = $DCParts -join ','


$OrganizationalUnits = @(
    @{Name = "Servers";  Children = @("DomainControllers", "MemberServers")}
    @{Name = "Workstations";  Children = @("NVCLIENT01")}
    @{Name = "Users";  Children = @("Management", @{ Name = "IT"; Children = @("Admins") }, "Consulting", "Finance", "HR")}
    @{Name = "Disabled"; Children = @("")}
    @{Name = "Groups"; Children = @("Security", "Distribution")}
)

function New-OU ($Data) {
    foreach ($Parent in $Data){
        foreach ($Child in $Parent.Children){
            if ($Child -is [string]) {
                if ($Child) {
                    if ($ExtraParent){
                        $OU = "OU=$Child,OU=$($Parent.Name),$ExtraParent$Domain"
                        Write-Host $OU
                    }
                    else{
                        $OU = "OU=$Child,OU=$($Parent.Name),$Domain"
                        Write-Host $OU
                    }
                }
                }
            else {
                $ExtraParent = "OU=$($Parent.Name),"
                $NewRun = $Child
                New-OU($NewRun)
            }
        }
    }
}

New-OU($OrganizationalUnits)