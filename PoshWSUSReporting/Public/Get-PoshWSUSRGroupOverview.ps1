function Get-PoshWSUSRGroupOverview
{
<#
.SYNOPSIS
Output a general compliance overview of a specific WSUS group regardless of approval status.

.DESCRIPTION
Output an object containing compliance info per server of an updated group. Only note Critical, 
Security, and Updates updates. 

.EXAMPLE 
Get-PoshWSUSRGroupOverview -ID b147aa1d-424b-4baa-99c8-a7d7ef7a394f

DESCRIPTION:
Generate a compliance report for the group b147aa1d-424b-4baa-99c8-a7d7ef7a394f

.EXAMPLE
Get-PoshWSUSRGroup 'Exchange Servers' | Get-PoshWSUSRGroupOverview

DESCRIPTION:
Take a group from Get-PoshWSUSRGroup and generate a compliance report. 

.NOTES
Author: Joey Piccola
Last Modified: 06.29.16
#>

    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline,ValueFromPipelineByPropertyname)]
        [guid[]]$Id
    )

    begin
    {
        if ($script:wsus -eq $null)
        {
            Write-Warning "No connection to a WSUS server has been defined."
            break
        }
    }
    process
    {
        # get the group you want info on
        $group = $wsus.GetComputerTargetGroup($id.guid)
        # create a new update scope
        $updatescope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
        # get all classifications and filter the ones we are interested in (this should match what classifications are selected in wsus if you want it to be accurate)
        $classifications = $wsus.GetUpdateClassifications() | ?{$_.Title -eq "Critical Updates" -or $_.Title -eq "Security Updates" -or $_.title -eq "Definition Updates"}
        # for the classifications we are interested in add them to our updatescope
        $updatescope.Classifications.AddRange($classifications)
        # define all the approved states we are interested in (all but "Any" & "Declined". see: https://goo.gl/Ebsi5c for details)
        $UpdateScope.ApprovedStates = [Microsoft.UpdateServices.Administration.ApprovedStates]'LatestRevisionApproved,HasStaleUpdateApprovals,NotApproved'
        # given the update scope we have defined go get all the updates on the wsus server
        $AnyAllUpdates = $wsus.GetUpdates($updatescope)
        # create a new computer scope
        $computerscope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope
        # since we have downstream wsus servers that we roll up to our master lets include those targets
        $ComputerScope.IncludeDownstreamComputerTargets = $True
        # add the group we just got to the computer scope we made earlier
        $computerscope.ComputerTargetGroups.add($group)
        # via the GetSummariesPerComputerTarget method, use both our update and computer scope to grab all our targets of interest
        $targets = $wsus.GetSummariesPerComputerTarget($updatescope,$computerscope) 
        # this is our "completed target objects" array where we will store our retrieved data for each server
        $target_objects = @()
        # this is when we last pulled down a sync from Microsoft (not used)
        $lastSync = $wsus.GetSubscription().getlastsynchronizationinfo().startTime
        # set global msrc counter varaiables
        $GlobalmsrcCritical = 0
        $GlobalmsrcImportant = 0
        $GlobalmsrcModerate = 0
        $GlobalmsrcLow = 0

        $totalTargetsProcessed = 0

        $nineComp = 0
        $eightComp = 0
        $sevenComp = 0
        $sixComp = 0
        $elseComp = 0

        foreach ($target in $targets)
        {
            # since we made it this far lets assume that out computer target is valid and ++ our counter
            $totalTargetsProcessed++

            # via the target guid go and get additinal info for the target
            $targetMeta = $wsus.GetComputerTarget([guid]$target.ComputerTargetId)
            # based on the target's info try and calc a needed updates count
            $NeededCount = ($target.DownloadedCount + $target.NotInstalledCount)
            # compliance
            $Compliant = (($target.InstalledCount)/($($AnyAllUpdates.Count) - $target.notApplicablecount))
            # create a complicance percentage. (Installed / (All - NotApplicable)) = gives us a pretty %
            $CompliantPercentage = '{0:P}' -f $Compliant
            # via the GetComputerTargetbyname method get a detailed summary what of updates are needed based on the UpdateInstallationStates of Downloaded and NotInstalled
            $neededUpdates = ($WSUS.GetComputerTargetbyname($targetMeta.FullDomainName)).GetUpdateInstallationInfoPerUpdate() | ?{(($_.UpdateInstallationState -eq "Downloaded") -or ($_.UpdateInstallationState -eq "notinstalled"))}

            # zero out all of our counters that we'll use for uptate type tracking
            $securityUpdatesCount = 0
            $criticalUpdatesCount = 0
            $updatesUpdatesCount = 0
            $other = 0
            $msrcCritical = 0
            $msrcImportant = 0
            $msrcModerate = 0
            $msrcLow = 0

            # eval all of the retrieved needed updates
            if ($neededUpdates -ne $null)
            {
                foreach ($update in $neededUpdates)
                {
                    # resolve our update to get additional info
                    $updateMeta = $wsus.GetUpdate([Guid]$update.updateid)
                    # process Microsoft Security Response Center (MSRC)
                    switch ($updateMeta.MsrcSeverity)
                    {
                        'Critical' { $msrcCritical++; $GlobalmsrcCritical++ }
                        'Important' { $msrcImportant++; $GlobalmsrcImportant++ }
                        'Moderate' { $msrcModerate++; $GlobalmsrcModerate++ }
                        'Low' { $msrcLow++; $GlobalmsrcLow++ }
                    }
                    # process classifications
                    switch ($updateMeta.UpdateClassificationTitle)
                    {
                        'Updates' { $updatesCount++ }
                        'Security Updates' { $securityUpdatesCount++ }
                        'Critical Updates' { $criticalUpdatesCount++ }
                        Default { $other++ }
                    }
                }
            }

            # define and popualte a hash containing all the goods
            $target_props = @{
                'FullDomainName' = $targetMeta.FullDomainName
                'OSDescription' = $targetMeta.OSDescription
                'LastSyncTime' = $targetMeta.LastSyncTime
                'LastSyncResult' = $targetMeta.LastSyncResult
                'LastReportedStatusTime' = $targetMeta.LastReportedStatusTime
                'TotalMissingUpdates' = $NeededCount
                'Compliance' = $CompliantPercentage
                'CriticalUpdates' = $criticalUpdatesCount
                'SecurityUpdates' = $securityUpdatesCount
                'UpdateUpdates' = $updatesUpdatesCount
                'MSRC-Critical' = $msrcCritical
                'MSRC-Important' = $msrcImportant
                'MSRC-Moderate' = $msrcModerate
                'MSRC-Low' = $msrcLow
                'ReportAge' = ($(get-date) - $($targetMeta.LastReportedStatusTime)).Days
            }
    
            # define a new object based off our hash from earlier (this allows us to create an array of objects)               
            $target_object = New-Object -TypeName PSObject -property $target_props
            # add our object to our target_objects array
            $target_objects += $target_object
        }
        Write-Output $target_objects
    }
    end {}
}