Install-WindowsFeature -name Web-Server -IncludeManagementTools
Set-Service -name W3SVC -startupType Automatic

Install-WindowsFeature -name RemoteAccess -IncludeManagementTools
Install-WindowsFeature -name Routing -IncludeManagementTools

#Install-RemoteAccess -DAInstallType FullInstall