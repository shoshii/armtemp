New-NetFirewallRule -DisplayName "Allow ICMPv4-In" -Protocol ICMPv4

Install-WindowsFeature -name Web-Server -IncludeManagementTools
Set-Service -name W3SVC -startupType Automatic

#Install-WindowsFeature -name RemoteAccess -IncludeManagementTools
#Install-WindowsFeature -name Routing -IncludeManagementTools

#Install-Module AzureAD