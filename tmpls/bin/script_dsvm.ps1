Param($AdminUserName)

New-NetFirewallRule -DisplayName "Allow ICMPv4-In" -Protocol ICMPv4

git clone https://github.com/Azure-Samples/cosmos-dotnet-getting-started C:\Users\$AdminUserName\cosmos-dotnet-getting-started\
git clone https://github.com/Azure-Samples/event-hubs-dotnet-ingest C:\Users\$AdminUserName\event-hubs-dotnet-ingest\
git clone https://github.com/Azure-Samples/azure-iot-samples-csharp C:\Users\$AdminUserName\azure-iot-samples-csharp\
git clone https://github.com/Azure/azure-kusto-labs C:\Users\$AdminUserName\azure-kusto-labs\