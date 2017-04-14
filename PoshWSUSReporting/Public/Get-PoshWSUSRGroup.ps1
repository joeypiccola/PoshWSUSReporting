function Get-PoshWSUSRGroup
{
<#
.SYNOPSIS
Get a WSUS group or all WSUS groups.  

.DESCRIPTION
Provided a WSUS group name go and get the group from WSUS. Use the -ListAll parameter to get
all the groups. 

.EXAMPLE 
Get-PoshWSUSRGroup -Name 'My Servers'

DESCRIPTION:
Search the KeePass database for a Title that matches Contoso and output the password for the entry.

.EXAMPLE 
Get-PoshWSUSRGroup -ListAll

DESCRIPTION:
Get all the groups on the WSUs servers.

.NOTES
Author: Joey Piccola
Last Modified: 06.24.16
#>

    [CmdletBinding()]
    Param (
        [Parameter()]
        [string]$Name
        ,
        [Parameter()]
        [switch]$ListAll
    )

    begin
    {
        Write-Verbose "Verifying WSUS connection"
        if ($WSUS -eq $null)
        {
            Write-Warning "No connection to WSUS was found via the connection variable `$wsus"
            break
        }    
    }
    process
    { 
        try
        {
            $GetUpdateGroup = $WSUS.GetComputerTargetGroups()
        
        }
        catch
        {
            Write-Warning "Failed to collect groups from the WSUS database $($script:wsus.Name)."
            break
        }
        
        if ($ListAll)
        {
            Write-Output $GetUpdateGroup
        }
        else
        {
            
            $GetUpdateGroup = $WSUS.GetComputerTargetGroups() | Where {$_.name -eq $Name}
            if ($GetUpdateGroup)
            {
                Write-Output $GetUpdateGroup
            }
            else
            {
                Write-Warning "Failed to find group $Name in the WSUS database $($script:wsus.Name)."
            }            
        }
    }
    end {}
}