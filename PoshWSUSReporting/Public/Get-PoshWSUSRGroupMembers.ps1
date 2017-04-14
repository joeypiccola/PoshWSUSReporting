function Get-PoshWSUSRGroupMembers
{
<#
.SYNOPSIS
List the members of a WSUS group. 

.DESCRIPTION
Provided a WSUS group and get the members of it. This does not include members of a group from a
downstream server!

.EXAMPLE 
Get-PoshWSUSRGroupMembers -Name 'Contoso Exchange Servers'

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