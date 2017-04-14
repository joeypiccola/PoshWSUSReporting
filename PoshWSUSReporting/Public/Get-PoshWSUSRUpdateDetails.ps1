function Get-PoshWSUSRUpdateDetails
{
<#
.SYNOPSIS
Get additional info for an update. 

.DESCRIPTION
Provided an update ID search WSUS for the update

.EXAMPLE 
Get-PoshWSUSRUpdateDetails -UpdatedID 1234-56789-abcde-fghij-klmnop

DESCRIPTION:
Get info for the update 1234-56789-abcde-fghij-klmnop

.EXAMPLE 
Get-PoshWSUSRComputerUpdates -FullDomainName server.contoso.com -Needed | Get-PoshWSUSRUpdateDetails

DESCRIPTION:
Get info for the updates that server.consoso.com needs. 

.NOTES
Author: Joey Piccola
Last Modified: 06.29.16
#>

    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipelineByPropertyname)]
        [string[]]$UpdateID
        ,
        [Parameter(ValueFromPipelineByPropertyname)]
        [string[]]$SecurityBulletins
        ,
        [Parameter(ValueFromPipelineByPropertyname)]
        [string[]]$UpdateInstallationState
        ,
        [Parameter(ValueFromPipelineByPropertyname)]
        [string[]]$UpdateApprovalAction        
        ,
        [Parameter(ValueFromPipelineByPropertyname)]
        [string[]]$FullDomainName
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
        $updateSearch = $script:AnyAllUpdates | ?{$_.id.updateid -eq "$UpdateID"} 
        if ($updateSearch)
        {
            
            $update_props = @{
                'UpdateInstallationState' = $UpdateInstallationState -join ','
                'UpdateApprovalAction' = $UpdateApprovalAction -join ','
                'FullDomainName' = $FullDomainName -join ','
                'SecurityBulletins' = $SecurityBulletins -join ','
                'UpdateSource' = $updateSearch.UpdateSource
                'KnowledgebaseArticles' = $updateSearch.KnowledgebaseArticles -join ','
                'ArrivalDate' = $updateSearch.ArrivalDate
                'LegacyName' = $updateSearch.LegacyName
                'UpdateClassificationTitle' = $updateSearch.UpdateClassificationTitle
            }                
            $update_object = New-Object -TypeName PSObject -property $update_props
            write-output $update_object
        }
        else
        {
            Write-Warning "$UpdateID was not found"
        }
    }
    end {}
}