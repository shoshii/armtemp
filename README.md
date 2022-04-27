# armtemp

Azure ARM テンプレート サンプル集です。

## azure cli での使い方

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

```
$ az deployment group create --resource-group <リソースグループ名> --template-file <テンプレートファイル名> --parameters clientIp=<自分のグローバルIP>
```

#### Ubuntu構築

```
$ az deployment group create --resource-group rg426ubu --template-file tmpls/ubuntu.bicep --parameters adminPublicKey="`cat ~/.ssh/id_rsa.pub`" clientIp=124.142.112.150 networkAddrB=30
```

### リソースグループ削除

```
$ az group delete --resource-group <リソースグループ名>
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

### 基本知識
- [Bicepとは](https://docs.microsoft.com/ja-jp/azure/azure-resource-manager/bicep/overview?tabs=bicep)
- [VSCode で Bicepファイルを作成する](https://docs.microsoft.com/ja-jp/azure/azure-resource-manager/bicep/quickstart-create-bicep-use-visual-studio-code?tabs=CLI)
- [Azure CLI で ARM のデプロイテンプレートを使用する方法](https://docs.microsoft.com/ja-jp/azure/azure-resource-manager/templates/deploy-cli)
- [Azure CLI でサインインする](https://docs.microsoft.com/ja-jp/cli/azure/authenticate-azure-cli)
- [Azure CLI でサブスクリプションを管理する](https://docs.microsoft.com/ja-jp/cli/azure/manage-azure-subscriptions-azure-cli)