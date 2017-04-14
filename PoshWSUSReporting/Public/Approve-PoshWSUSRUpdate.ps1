function Approve-PoshWSUSRUpdate
{     
<#
.SYNOPSIS
Approve an update for a WSUS group.

.DESCRIPTION
Via the description ID for an updated approve the update for a specific WSUS group. 

.EXAMPLE 
Approve-PoshWSUSRUpdate -UpdatedID 1234-56789-abcde-fghij-klmnop -UpdatedGroup "Server Group Uno"

DESCRIPTION:
Approve an updated for the group "Server Group Uno"

.EXAMPLE 
Get-PoshWSUSRGroupUpdateSummary -UpdateGroup "Server Group Uno" -Needed | Approve-PoshWSUSRUpdate -UpdateGroup "Server Group Uno"

DESCRIPTION:
Get all the udpates that are needed for the group "Server Group Uno" and approve them

.NOTES
Author: Joey Piccola
Last Modified: 06.25.16
#>

    [CmdletBinding()]
    Param (
        [Parameter()]
        [string]$UpdateGroup
        ,
        [Parameter(ValueFromPipelineByPropertyname)]
        [string[]]$UpdateID
    )

    begin
    {
        Write-Verbose "Verifying WSUS connection"
        if ($WSUS -eq $null)
        {
            Write-Warning "No connection to WSUS was found via the connection variable `$wsus"
            break
        }
        
        if (!($script:AnyAllUpdates))
        {
            Write-Warning "There doesn't seem to be any contents in `$AnyAllUpdates. Did you run Get-PoshWSUSRServerUpdates?"
            break
        }             
    }
    process
    {
        $uGroup = Get-PoshWSUSRGroup -Name $UpdateGroup
        $patchMatch = $script:AnyAllUpdates | ?{$_.id.updateid -eq "$UpdateID"}
        if ($patchMatch)
        {
            if ($patchMatch.RequiresLicenseAgreementAcceptance -eq $true) 
            {
                $patchMatch.AcceptLicenseAgreement()
            }			
        
            $patchMatch.Approve("Install",$uGroup)
        }
        else
        {
            Write-Warning "No update was found for $UpdateID."
        }   
    }
    end {}
}