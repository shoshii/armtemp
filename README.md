# armtemp

Azure ARM テンプレート サンプル集です。

## Azure CLI での使い方

### サインイン
```
$ az login
$ az account show
# 自分のサブスクリプションではなかったら一覧を調べる
$ az account list --output table
# 自分のサブスクリプションにセット
$ az account set -n <subscription id>
```

### リソースグループ作成

```
$ az group create --name <リソースグループ名> --location japaneast
```

### ARM テンプレートを用いたデプロイ

tmpls/net/spokehub.bicep でデプロイする場合
```
$ az deployment group create --resource-group <リソースグループ名> --template-file tmpls/net/spokehub.bicep --parameters params/parameters.json
```

#### Ubuntu構築

```
$ az deployment group create --resource-group rg426ubu --template-file tmpls/ubuntu.bicep --parameters adminPublicKey="`cat ~/.ssh/id_rsa.pub`" clientIp=124.142.112.150 networkAddrB=30
```

### リソースグループ削除

```
$ az group delete --resource-group <リソースグループ名>
```

### ADX クラスター依存関係取得

```
$ Set-ExecutionPolicy Unrestricted -Scope Process
$ misc/get_adx_dependencies.ps1 <subscription id> <adx cluster name> <resource group name>
```

## 参考資料

### サンプル集
- [VM作成](https://docs.microsoft.com/ja-jp/azure/virtual-machines/windows/ps-template)
- [VPN Gateway作成](https://docs.microsoft.com/en-us/azure/templates/microsoft.network/virtualnetworkgateways?tabs=bicep)
  - 末尾にサンプル集あり
- [VPN Gatewayテンプレートサンプル](https://github.com/Azure/azure-quickstart-templates/blob/master/demos/arm-asm-s2s/azuredeploy.json)
- [Databricks VNet Injection サンプル](https://github.com/Azure/azure-quickstart-templates/blob/master/quickstarts/microsoft.databricks/databricks-all-in-one-template-for-vnet-injection/main.bicep)
- [Cosmos DB サンプル](https://github.com/Azure/azure-quickstart-templates/blob/master/quickstarts/microsoft.documentdb/cosmosdb-sql/main.bicep)
- [Linux インストール時スクリプトサンプル](https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/custom-script-linux)
- [Windows インストール時スクリプトサンプル](https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/custom-script-windows)
- [Azure Firewall サンプル](https://github.com/Azure/azure-quickstart-templates/blob/master/quickstarts/microsoft.network/azurefirewall-create-with-firewallpolicy-apprule-netrule-ipgroups/azuredeploy.json)
- [Bastion サンプル](https://github.com/Azure/azure-quickstart-templates/blob/master/quickstarts/microsoft.network/azure-bastion/main.bicep)
- [Cosmos プライベート エンドポイント サンプル](https://github.com/Azure/azure-quickstart-templates/blob/master/quickstarts/microsoft.documentdb/cosmosdb-private-endpoint/main.bicep)
- [SQL Server Managed Instance サンプル](https://github.com/Azure/azure-quickstart-templates/blob/master/demos/azure-sql-managed-instance/azuredeploy.json)
- [HDInsight サンプル](https://github.com/Azure/azure-quickstart-templates/blob/master/quickstarts/microsoft.hdinsight/hdinsight-datalake-store-azure-storage/azuredeploy.json)
- [HDI パブリックアクセス制限サンプル](https://github.com/Azure-Samples/hdinsight-enterprise-security/tree/main/ESP-HIB-PL-Template)
- [Data Lake Gen2 サンプル](https://gist.github.com/dazfuller/0740f1640225dc8ea0eb29a8e6f88a6a)
- [Role Assign サンプル](https://docs.microsoft.com/ja-jp/azure/role-based-access-control/role-assignments-template)

### 基本知識

#### bicep, arm テンプレート, Azure CLI
- [Bicepとは](https://docs.microsoft.com/ja-jp/azure/azure-resource-manager/bicep/overview?tabs=bicep)
- [VSCode で Bicepファイルを作成する](https://docs.microsoft.com/ja-jp/azure/azure-resource-manager/bicep/quickstart-create-bicep-use-visual-studio-code?tabs=CLI)
- [Bicepでループ処理](https://blog.ivemo.se/Using-loops-with-Bicep/)
- [Azure CLI で ARM のデプロイテンプレートを使用する方法](https://docs.microsoft.com/ja-jp/azure/azure-resource-manager/templates/deploy-cli)
- [Azure CLI でサインインする](https://docs.microsoft.com/ja-jp/cli/azure/authenticate-azure-cli)
- [Azure CLI でサブスクリプションを管理する](https://docs.microsoft.com/ja-jp/cli/azure/manage-azure-subscriptions-azure-cli)

#### デバッグ
- [enable debug log](https://docs.microsoft.com/en-us/azure/azure-resource-manager/troubleshooting/enable-debug-logging?tabs=azure-cli)

#### RBAC
- [Role Assign の基本知識](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/scenarios-rbac)

#### ネットワーク
- [プライベート エンドポイント ネットワーク ポリシー](https://docs.microsoft.com/ja-jp/azure/private-link/disable-private-endpoint-network-policy)
- [サービス エンドポイント ポリシー](https://docs.microsoft.com/ja-jp/azure/virtual-network/virtual-network-service-endpoint-policies-overview)
- [サービス エンドポイントとプライベート エンドポイントの違い](https://qiita.com/taka_s/items/340c9c52f1e948f0f753)
- [DNS Forwarder](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-name-resolution-for-vms-and-role-instances#vms-and-role-instances)

#### HDInsight
- [HDIでプライベート リンクを有効にする](https://docs.microsoft.com/ja-jp/azure/hdinsight/hdinsight-private-link)