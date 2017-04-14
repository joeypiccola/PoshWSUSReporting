function Connect-PoshWSUSr
{
<#
.SYNOPSIS
Connect to a WSUS server. 

.DESCRIPTION
Provided a hostname and a port attempt to connect to a WSUS server and write a connection variable 
named $wsus to the parent variable scope. For connections to a local wsus server do not provide 
either the -hostname or -port parameter, bur rather simply use the -LocalConnection parameter.

.EXAMPLE 
Connect-PoshWSUSr -HostName wsus.contoso.com -Port 8530

DESCRIPTION:
Connect to a remote WSUS Server.

.EXAMPLE 
Connect-PoshWSUSr -LocalConnection

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
            Write-Warning "Please specify the appropriate parameter or combination of parameters for connecting to a WSUS"
        }
        Write-Output $script:wsus
    }
    end {}
}