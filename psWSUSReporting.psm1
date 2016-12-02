function Connect-psWSUSr
{
<#
.SYNOPSIS
Connect to a WSUS server. 

.DESCRIPTION
Provided a hostname and a port attempt to connect to a WSUS server and write a connection variable 
named $wsus to the parent variable scope. For connections to a local wsus server do not provide 
either the -hostname or -port parameter, bur rather simply use the -LocalConnection parameter.

.EXAMPLE 
Connect-psWSUSr -HostName wsus.contoso.com -Port 8530

DESCRIPTION:
Connect to a remote WSUS Server.

.EXAMPLE 
Connect-psWSUSr -LocalConnection

DESCRIPTION:
Connect to a local WSUS Server.

.NOTES
Author: Joey Piccola
Last Modified: 06.23.16
#>

    [CmdletBinding()]
    Param (
        [Parameter()]
        [ValidateScript({Test-Connection -ComputerName $_ -Count 3})]
        [string]$Hostname
        ,
        [Parameter()]
        [int]$Port
        ,
        [Parameter()]
        [switch]$LocalConnection
    )

    begin {}
    process
    {
        # null out any previous connection to WSUS in the parent var scope	    
        $script:wsus = $null
        [void][reflection.assembly]::loadwithpartialname("microsoft.updateservices.administration")
        
        # atttempt to connect to WSUS either locally or remote and set a connection variable in the parent scope
        if ($LocalConnection)
        {
            $script:wsus = [microsoft.updateservices.administration.adminproxy]::getupdateserver()
        }
        elseif (($Hostname) -and ($Port))
        {
            
	        $script:wsus = [microsoft.updateservices.administration.adminproxy]::getupdateserver($Hostname,$false,$Port)
        }
        else
        {
            Write-Warning "Please specify the appropriate parameter or combination of parameters for connecting to a WSUS” 
        }
        Write-Output $script:wsus
    }
    end {}
}

function Get-psWSUSrComputerUpdates
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
Get-psWSUSrComputerUpdates -FullDomainName srv1.contoso.com -Needed

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

function Get-psWSUSrGroupUpdateSummary
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
Get-psWSUSrGroupUpdateSummary -UpdateGroup 'SCCM MS Servers' -NotApprovedAndNeeded

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
            $UpdateGroupMembers = Get-psWSUSrGroupMembers -Name $UpdateGroup
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
                $computerUpdates = Get-psWSUSrComputerUpdates -FullDomainName $UpdateGroupMember.FullDomainName -ApprovedDownloadedAndReadyForInstall
            }
            elseif ($NotApprovedAndNeeded)
            {
                $computerUpdates = Get-psWSUSrComputerUpdates -FullDomainName $UpdateGroupMember.FullDomainName -NotApprovedAndNeeded
            }
            elseif ($AnyApprovedAndApplicable)
            {
                $computerUpdates = Get-psWSUSrComputerUpdates -FullDomainName $UpdateGroupMember.FullDomainName -AnyApprovedAndApplicable
            }
            elseif ($ApprovedAndNeededButNotDownloaded)
            {
                $computerUpdates = Get-psWSUSrComputerUpdates -FullDomainName $UpdateGroupMember.FullDomainName -ApprovedAndNeededButNotDownloaded
            }
            elseif ($Needed)
            {
                $computerUpdates = Get-psWSUSrComputerUpdates -FullDomainName $UpdateGroupMember.FullDomainName -Needed
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

function Get-psWSUSrGroupMembers
{
<#
.SYNOPSIS
List the members of a WSUS group. 

.DESCRIPTION
Provided a WSUS group and get the members of it. This does not include members of a group from a
downstream server!

.EXAMPLE 
Get-psWSUSrGroupMembers -Name 'Contoso Exchange Servers'

DESCRIPTION:
Get all the members from the group 'Contoso Exchange Servers'.

.NOTES
Author: Joey Piccola
Last Modified: 12/02/16
#>

    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline,ValueFromPipelineByPropertyname)]
        [string[]]$Name
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
        
        Write-Verbose "Pulling members from upstream server: $($script.wsus.fulldomainname)"
        $GetUpdateGroup = $WSUS.GetComputerTargetGroups() | Where {$_.name -eq $Name}
        if ($GetUpdateGroup)
        {
            $UpdateGroupMembers = $wsus.getComputerTargetGroup($GetUpdateGroup.Id).GetComputerTargets()
            Write-Verbose "Found $($UpdateGroupMembers.count)x"
            foreach ($UpdateGroupMember in $UpdateGroupMembers)
            {   
                Write-output $UpdateGroupMember
            }

            # go and connect to the downstream server and write out group members from that group as well. this is a mess
            $downstreamServers = $wsus.GetDownstreamServers()
            if ($downstreamServers)
            {
                foreach ($downstreamServer in $downstreamServers)
                {
                    Write-Verbose "Connecting to downstream server $($downstreamServer.fulldomainname)"
                    # connect to the downstream server
                    $dsConnection = $null
                    $dsConnection = [microsoft.updateservices.administration.adminproxy]::getupdateserver($downstreamServer.fulldomainname,$false,8530)
                    # get the computer from the same group from the downstream
                    $GetUpdateGroup = $null
                    $GetUpdateGroup = $dsConnection.GetComputerTargetGroups() | Where {$_.name -eq $Name}
                    $UpdateGroupMembers = $dsConnection.getComputerTargetGroup($GetUpdateGroup.Id).GetComputerTargets()
                    Write-Verbose "Pulling members from downstream server: $($dsConnection.name)"
                    foreach ($UpdateGroupMember in $UpdateGroupMembers)
                    {   
                        Write-output $UpdateGroupMember
                    }
                }
            }
        }
        else
        {
            Write-Warning "Failed to find group $Name in the WSUS database $($script:wsus.Name)."
        }                       
    }
    end {}
}

function Get-psWSUSrGroup
{
<#
.SYNOPSIS
Get a WSUS group or all WSUS groups.  

.DESCRIPTION
Provided a WSUS group name go and get the group from WSUS. Use the -ListAll parameter to get
all the groups. 

.EXAMPLE 
Get-psWSUSrGroup -Name 'My Servers'

DESCRIPTION:
Search the KeePass database for a Title that matches Contoso and output the password for the entry.

.EXAMPLE 
Get-psWSUSrGroup -ListAll

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

function Approve-psWSUSrUpdate
{     
<#
.SYNOPSIS
Approve an update for a WSUS group.

.DESCRIPTION
Via the description ID for an updated approve the update for a specific WSUS group. 

.EXAMPLE 
Approve-psWSUSrUpdate -UpdatedID 1234-56789-abcde-fghij-klmnop -UpdatedGroup "Server Group Uno"

DESCRIPTION:
Approve an updated for the group "Server Group Uno"

.EXAMPLE 
Get-psWSUSrGroupUpdateSummary -UpdateGroup "Server Group Uno" -Needed | Approve-psWSUSrUpdate -UpdateGroup "Server Group Uno"

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
            Write-Warning "There doesn't seem to be any contents in `$AnyAllUpdates. Did you run Get-psWSUSrServerUpdates?"
            break
        }             
    }
    process
    {
        $uGroup = Get-psWSUSrGroup -Name $UpdateGroup
        $patchMatch = $script:AnyAllUpdates | ?{$_.id.updateid -eq "$UpdateID"}
        if ($patchMatch)
        {
            if ($patchMatch.RequiresLicenseAgreementAcceptance -eq $true) 
            {
                $patchMatch.AcceptLicenseAgreement()
            }			
        
            $patchMatch.Approve(“Install”,$uGroup)
        }
        else
        {
            Write-Warning "No update was found for $UpdateID."
        }   
    }
    end {}
}

function Get-psWSUSrServerUpdates
{
<#
.SYNOPSIS
Get all updates from all sync's on the WSUS server.

.DESCRIPTION
This cmdlet gets all the updates on the WSUS server for use by other cmdlets when additional info
is needed for the updated. This cmdlet sets the variable $AnyAllUpdates in the parent scope with
the updated info.  

.EXAMPLE 
Get-psWSUSrServerUpdates 

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

function Get-psWSUSrUpdateDetails
{
<#
.SYNOPSIS
Get additional info for an update. 

.DESCRIPTION
Provided an update ID search WSUS for the update

.EXAMPLE 
Get-psWSUSrUpdateDetails -UpdatedID 1234-56789-abcde-fghij-klmnop

DESCRIPTION:
Get info for the update 1234-56789-abcde-fghij-klmnop

.EXAMPLE 
Get-psWSUSrComputerUpdates -FullDomainName server.contoso.com -Needed | Get-psWSUSrUpdateDetails

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
            Write-Warning "There doesn't seem to be any contents in `$AnyAllUpdates. Did you run Get-psWSUSrServerUpdates?"
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

function Get-psWSUSrGroupOverview
{
<#
.SYNOPSIS
Output a general compliance overview of a specific WSUS group regardless of approval status.

.DESCRIPTION
Output an object containing compliance info per server of an updated group. Only note Critical, 
Security, and Updates updates. 

.EXAMPLE 
Get-psWSUSrGroupOverview -ID b147aa1d-424b-4baa-99c8-a7d7ef7a394f

DESCRIPTION:
Generate a compliance report for the group b147aa1d-424b-4baa-99c8-a7d7ef7a394f

.EXAMPLE
Get-psWSUSrGroup 'Exchange Servers' | Get-psWSUSrGroupOverview

DESCRIPTION:
Take a group from Get-psWSUSrGroup and generate a compliance report. 

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