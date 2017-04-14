function Get-PoshWSUSRGroupUpdateSummary
{
<#
.SYNOPSIS
Get specific update details for a specified computer group.

.DESCRIPTION
Based on one of the switched parameters provided get updates for a selected computer group. The
switches vary from getting all updates that are currently installed to only getting updates that
are needed. Below is a breakdown of what the switches do.

-ApprovedDownloadedAndReadyForInstall
Updates that are approved and have reported a status of downloaded for the group. 

-NotApprovedAndNeeded
Updates that are applicable to the system and not approved. 

-Installed
Updates that are installed on the computer. 

-AnyApprovedAndApplicable
Any update that has been approved for a computer regardless of it's installation state.

-ApprovedAndNeededButNotDownloaded
Updates that have been approved but are not downloaded to the computer. 

-Needed
Updates that are not installed on the computer regardless of approval or local update state 
(e.g. downloaded).

.EXAMPLE 
Get-PoshWSUSRGroupUpdateSummary -UpdateGroup 'SCCM MS Servers' -NotApprovedAndNeeded

DESCRIPTION:
Query WSUS and get all the updates that are not approved and needed for the group 'SCCM MS Servers'

.NOTES
Author: Joey Piccola
Last Modified: 06.24.16
#>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
        [Alias('Name')] 
        [string[]]$UpdateGroup        
        ,
        [Parameter()]
        [switch]$ApprovedDownloadedAndReadyForInstall
        ,
        [Parameter()]
        [switch]$NotApprovedAndNeeded
        ,
        [Parameter()]
        [switch]$Installed
        ,
        [Parameter()]
        [switch]$AnyApprovedAndApplicable
        ,
        [Parameter()]
        [switch]$ApprovedAndNeededButNotDownloaded
        ,
        [Parameter()]
        [switch]$Needed
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
            $UpdateGroupMembers = Get-PoshWSUSRGroupMembers -Name $UpdateGroup
            Write-Verbose "Successfully connected to $($script:wsus.Name)"
        }
        catch
        {
            Write-Warning "Thee specified item $UpdateGroup could not be found in the WSUS database $($script:wsus.Name)."
            break
        }

        $updatesOfInterestArray = @()
        foreach ($UpdateGroupMember in $UpdateGroupMembers)
        {   
            if ($ApprovedDownloadedAndReadyForInstall)
            {
                $computerUpdates = Get-PoshWSUSRComputerUpdates -FullDomainName $UpdateGroupMember.FullDomainName -ApprovedDownloadedAndReadyForInstall
            }
            elseif ($NotApprovedAndNeeded)
            {
                $computerUpdates = Get-PoshWSUSRComputerUpdates -FullDomainName $UpdateGroupMember.FullDomainName -NotApprovedAndNeeded
            }
            elseif ($AnyApprovedAndApplicable)
            {
                $computerUpdates = Get-PoshWSUSRComputerUpdates -FullDomainName $UpdateGroupMember.FullDomainName -AnyApprovedAndApplicable
            }
            elseif ($ApprovedAndNeededButNotDownloaded)
            {
                $computerUpdates = Get-PoshWSUSRComputerUpdates -FullDomainName $UpdateGroupMember.FullDomainName -ApprovedAndNeededButNotDownloaded
            }
            elseif ($Needed)
            {
                $computerUpdates = Get-PoshWSUSRComputerUpdates -FullDomainName $UpdateGroupMember.FullDomainName -Needed
            }
            else
            {
                Write-Warning "No relevant -parameter was specified (e.g. -Needed)"
            }
                        
            if ($computerUpdates)
            {
                $updatesOfInterestArray += $computerUpdates
            }
        }
        $updatesOfInterestArrayUnique = $updatesOfInterestArray | select * -ExcludeProperty fulldomainname | sort -Property updateid -Unique
        Write-Output $updatesOfInterestArrayUnique 

    }
    end {}
}