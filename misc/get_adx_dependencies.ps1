Param($subscriptionId, $clusterName, $resourceGroupName)
$apiversion = '2022-02-01'

armclient get /subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Kusto/clusters/$clusterName/OutboundNetworkDependenciesEndpoints?api-version=$apiversion