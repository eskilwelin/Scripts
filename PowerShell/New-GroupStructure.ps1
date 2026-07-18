<#
.SYNOPSIS
    Creates the top level group structure under a given top level OU and domain root.
.PARAMETER Root
    Domain in dotted form, e.g. corp.nordvik.se. Converted to DC= parts internally.
.EXAMPLE
    .\New-GroupStructure.ps1 -Import .\groups.json -Root "corp.nordvik.se" -OrgName "Nordvik"
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [parameter(Mandatory=$true)][string]$Import,
    [parameter(Mandatory=$true)][string]$Root,
    [parameter(Mandatory=$true)][string]$OrgName
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

$ADGroups = Get-Content -Raw $Import | ConvertFrom-Json

foreach ($Group in $ADGroups){
    Try{
        $Category = $Group.category
        if ($Category -eq "Security" -or $Category -eq "Distribution") {
            $Path = "OU=$Category,OU=Groups,OU=$OrgName,$Domain"
        }
        else{
            Write-Verbose "Invalid category: $Category"
            Continue
        }

        $GroupInfo = @{
            Name = $Group.name
            GroupScope = $Group.scope
            GroupCategory = $Category
            Path = $Path
            Description = $Group.description
        }

        if (Get-ADGroup -Filter "Name -eq '$($Group.name)'"){
            Write-Verbose "A group with the name $($Group.name) already exists."
            Continue
        }
        if ($PSCmdlet.ShouldProcess($Group.name, "Creating group")){
            New-ADGroup @GroupInfo
            Write-Verbose "The group $($Group.name) was created."
        }

    }
    Catch{
        Write-Verbose "Failed to populate information for group '$($Group.name)' - $_" 
    }
}
