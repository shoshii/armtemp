Install-WindowsFeature -name Web-Server -IncludeManagementTools
Set-Service -name W3SVC -startupType Automatic

Install-WindowsFeature RemoteAccess -IncludeManagementTools