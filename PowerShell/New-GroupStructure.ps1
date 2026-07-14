<#
.SYNOPSIS
    Creates the top level security group structure
.PARAMETER Root
    Domain in dotted form, e.g. corp.nordvik.se. Converted to DC= parts internally.
.EXAMPLE
    New-ADGroup -Name "GRP_IT_Admins" `
            -GroupScope Global `
            -GroupCategory Security `
            -Path "OU=Security,OU=Groups,DC=corp,DC=nordvik,DC=se" `
            -Description "IT administrators — full admin on servers"
#>

