# armtemp

## azure cli での使い方

```
$ az login
$ az account show
# 自分のサブスクリプションではなかったら一覧を調べる
$ az account list --output table
# 自分のサブスクリプションにセット
$ az account set -n <subscription id>
```

## リソースグループ作成

```
$ az group create --name <リソースグループ名> --location japaneast
```

## DSVM のデプロイ

```
$ az deployment group create --resource-group <リソースグループ名> --template-file <テンプレートファイル名> --parameters clientIp=<自分のグローバルIP>
```

## リソースグループ削除

```
$ az group delete --resource-group <リソースグループ名>
```