# psWSUSReporting
This module is used for generating server compliance info from WSUS. It can also be used to approve updates for WSUS groups.

```
PS C:\blah> Get-PoshWSUSComputerUpdates -FullDomainName box.ad.piccola.us -ApproveddownloadedAndReadyForInstall | select -First 2

UpdateInstallationState   : Downloaded
Title                     : Cumulative Security Update for Internet Explorer 11 for Windows Server 2012 R2 (KB3160005)
UpdateID                  : 725ba22c-7559-49d3-bfbd-d51622148d0c
FullDomainName            : {box.ad.piccola.us}
UpdateClassificationTitle : Security Updates
UpdateApprovalAction      : Install
KnowledgebaseArticles     : {3160005}
HasSupersededUpdates      : True
IsSuperseded              : False
SecurityBulletins         : {MS16-063}

UpdateInstallationState   : Downloaded
Title                     : Security Update for Windows Server 2012 R2 (KB3161561)
UpdateID                  : d299f2c3-98fc-4266-ba0c-0c600fbcd70e
FullDomainName            : {box.ad.piccola.us}
UpdateClassificationTitle : Security Updates
UpdateApprovalAction      : Install
KnowledgebaseArticles     : {3161561}
HasSupersededUpdates      : True
IsSuperseded              : False
SecurityBulletins         : {MS16-075}
```

```
PS C:\blah> Get-PoshWSUSGroup -Name lab01.com  | Get-PoshWSUSGroupOverview | ft FullDomainName,Compliance,TotalMissingUpdates,CriticalUpdates,SecurityUpdates,LastSyncTime
0

FullDomainName       Compliance TotalMissingUpdates CriticalUpdates SecurityUpdates LastSyncTime
--------------       ---------- ------------------- --------------- --------------- ------------
ss01lab01.lab01.com  20.18 %                    178              15             163 6/30/2016 7:21:07 AM
ss02lab01.lab01.com  23.00 %                    154              15             139 6/30/2016 7:40:52 AM
ss03lab01.lab01.com  22.89 %                    155              15             140 6/30/2016 10:01:48 AM
app04lab01.lab01.com 46.90 %                    136              10             126 6/28/2016 2:21:18 PM
sql01lab01.lab01.com 20.18 %                    178              15             163 6/30/2016 9:17:25 AM
app01lab01.lab01.com 23.00 %                    154              15             139 6/30/2016 1:10:20 PM
app03lab01.lab01.com 23.00 %                    154              15             139 6/30/2016 4:04:46 AM
app02lab01.lab01.com 23.00 %                    154              15             139 6/30/2016 6:48:57 AM
dc01lab01.lab01.com  23.00 %                    154              15             139 6/30/2016 2:36:41 PM
```