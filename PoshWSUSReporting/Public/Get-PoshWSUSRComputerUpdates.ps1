function Get-PoshWSUSRComputerUpdates
{
<#
.SYNOPSIS
Get specific update detauks for a specified computer.

.DESCRIPTION
Based on one of the switched parameters provided get updates for a selected computer. The switches
vary from getting all updates that are currently installed to only getting updates that are
needed. Below is a breakdown of what the switches do. 

-ApprovedDownloadedAndReadyForInstall
Updates that are approved and have reported a status of downloaded on the computer. 

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
Get-PoshWSUSRComputerUpdates -FullDomainName srv1.contoso.com -Needed

DESCRIPTION:
Query WSUS and get all the updates that srv1.contoso.com needs.

.NOTES
Author: Joey Piccola
Last Modified: 06.24.16
#>

    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline,ValueFromPipelineByPropertyname,Mandatory)]
        [string[]]$FullDomainName
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
            $Updates = $null
            $Updates = ($WSUS.GetComputerTargetbyname($FullDomainName)).GetUpdateInstallationInfoPerUpdate()
            Write-Verbose "Successfully connected to $($script:wsus.Name)"
        }
        catch
        {
            Write-Warning "The specified item $FullDomainName could not be found in the WSUS database $($script:wsus.Name)."
            break
        }
        
        if ($NotApprovedAndNeeded)
        {
            $notInstalled = $Updates | ?{$_.UpdateInstallationState -eq 'NotInstalled'}
            $notApproved = $notInstalled | ?{$_.UpdateApprovalAction -eq 'NotApproved'}
            $updatesOfInterest = $notApproved
        }
        elseif ($ApprovedDownloadedAndReadyForInstall)
        {
            $downloaded = $Updates | ?{$_.UpdateInstallationState -eq 'Downloaded'}
            $updatesOfInterest = $downloaded
        }
        elseif ($AnyApprovedAndApplicable)
        {
            $notInstalled = $Updates | ?{$_.UpdateInstallationState -ne 'NotApplicable'}
            $ApprovedUpdates = $notInstalled | ?{$_.UpdateApprovalAction -eq 'Install'}
            $updatesOfInterest = $ApprovedUpdates
        }
        elseif ($Installed)
        {
            $installedUpdates = $Updates | ?{$_.UpdateInstallationState -eq 'Installed'}
            $updatesOfInterest = $installedUpdates
        }
        elseif ($ApprovedAndNeededButNotDownloaded)
        {
            $notInstalled = $Updates | ?{$_.UpdateInstallationState -eq 'NotInstalled'}
            $ApprovedUpdates = $notInstalled | ?{$_.UpdateApprovalAction -eq 'Install'}
            $updatesOfInterest = $ApprovedUpdates
        }
        elseif ($Needed)
        {
            $notInstalledorDownloaded = $Updates | ?{(($_.UpdateInstallationState -eq 'NotInstalled') -or ($_.UpdateInstallationState -eq 'Downloaded'))}
            $ApprovedUpdates = $notInstalledorDownloaded #| ?{$_.UpdateApprovalAction -eq 'All'}
            $updatesOfInterest = $ApprovedUpdates
        }
        else
        {
            Write-Warning "No scope parameter was provided (e.g. -NotApprovedAndNeeded)"
            break
        }
        Write-Verbose "Updates of interest count: $($updatesOfInterest.count)"
        $updateArray = @()
        foreach ($update in $updatesOfInterest)
        {
            $updateMeta = $wsus.GetUpdate([Guid]$update.updateid)
            $update_props = $null
            $update_props = @{
                'UpdateInstallationState' = $update.UpdateInstallationState
                'UpdateApprovalAction' = $update.UpdateApprovalAction
                'UpdateID' = $update.updateid
                'SecurityBulletins' = $updateMeta.SecurityBulletins
                'UpdateClassificationTitle' = $updateMeta.UpdateClassificationTitle
                'KnowledgebaseArticles' = $updateMeta.KnowledgebaseArticles
                'Title' = $updateMeta.Title
                'IsSuperseded' = $updateMeta.IsSuperseded
                'HasSupersededUpdates' = $updateMeta.HasSupersededUpdates
                'FullDomainName' = $FullDomainName
            }
            $update_object = New-Object -TypeName PSObject -property $update_props
            $updateArray += $update_object
        }
        Write-Output $updateArray
    }
    end {}
}