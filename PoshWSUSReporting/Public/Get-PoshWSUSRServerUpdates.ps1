function Get-PoshWSUSRServerUpdates
{
<#
.SYNOPSIS
Get all updates from all sync's on the WSUS server.

.DESCRIPTION
This cmdlet gets all the updates on the WSUS server for use by other cmdlets when additional info
is needed for the updated. This cmdlet sets the variable $AnyAllUpdates in the parent scope with
the updated info.  

.EXAMPLE 
Get-PoshWSUSRServerUpdates 

DESCRIPTION:
Get all the updates for the WSUS server and store them in the variable $script:AnyAllUpdates.

.NOTES
Author: Joey Piccola
Last Modified: 06.27.16
#>


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
        $script:AnyAllUpdates = $null
        $updatescope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
        $classifications = $wsus.GetUpdateClassifications() #| ?{$_.Title -eq "Critical Updates" -or $_.Title -eq "Security Updates"}# -or $_.title -eq "Updates"}
        $updatescope.Classifications.Clear()
        $updatescope.Classifications.AddRange($classifications)
        $script:AnyAllUpdates = $wsus.GetUpdates($updatescope)
        #Write-Output $AnyAllUpdates
    }
    end {}
}