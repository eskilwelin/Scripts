<#
.SYNOPSIS
    Creates the top level security group structure
.PARAMETER Domain
    Domain in dotted form, e.g. corp.nordvik.se. Converted to DC= parts internally.
.EXAMPLE
    .\New-GroupStructure.ps1 -Path .\groups.json -Domain "corp.nordvik.se"
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [parameter(Mandatory=$true)][string]$Path,
    [parameter(Mandatory=$true)][string]$Domain
)

Import-Module ActiveDirectory

$RootSplit = $Domain -split '\.'
$DCParts = $RootSplit | ForEach-Object { "DC=$_"}
$DCJoined = $DCParts -join ','

$ADGroups = Get-Content -Raw $Path | ConvertFrom-Json

foreach ($Group in $ADGroups){
    Try{
        $Category = $Group.category
        if ($Category -eq "Security" -or $Category -eq "Distribution") {
            $OU = "OU=$Category,OU=Groups,$DCJoined"
        }
        else{
            Write-Verbose "Invalid category: $Category"
            Continue
        }

        $GroupInfo = @{
            Name = $Group.name
            GroupScope = $Group.scope
            GroupCategory = $Category
            Path = $OU
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
