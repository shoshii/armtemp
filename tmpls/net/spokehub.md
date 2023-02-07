# Spoke Hub 構成

## VPN ゲートウェイと オンプレの ルーティング デバイスを接続する

### オンプレのルーティング デバイスのセットアップ

1. select server role
    * ![select server role](../../images/net/remote1.png)
1. select role service
    * ![select role service](../../images/net/remote2.png)
1. start to install roles
    * ![start install roles](../../images/net/remote3.png)
1. open wizard of Configuration for Direct Access and VPN
    * ![open wizard of Configuration for Direct Access and VPN](../../images/net/remote4.png)
1. select Deploy VPN only
    * ![select Deploy VPN only](../../images/net/remote5.png)
1. configure and enable Routing and Remote access
    * ![configure and enable Routing and Remote access](../../images/net/remote6.png)
1. select custom configuration
    * ![select custom configuration](../../images/net/remote7.png)
1. select Demand dial connections and LAN routing
    * ![select Demand dial connections and LAN routing](../../images/net/remote8.png)
1. add new Demand dial interface
    * ![add new Demand dial interface](../../images/net/remote9.png)
1. select VPN as connection type
    * ![select VPN as connection type](../../images/net/remote10.png)
1. select IKEv2 as type of VPN connection
    * ![select IKEv2 as type of VPN connection](../../images/net/remote11.png)
1. set the VPN gateway IP as destination address
    * ![set VPN gateway IP as destination address](../../images/net/remote12.png)
1. select route IP packets on this interface
    * ![select route IP packets on this interface](../../images/net/remote13.png)
1. set the hub network address prefix on static route
    * ![set hub network address prefix on static route](../../images/net/remote14.png)
1. set the spoke network address prefix on static route
    * ![set spoke network address prefix on static route](../../images/net/remote15.png)
1. set the shared key for VPN IKEv2
    * ![set shared key for VPN IKEv2](../../images/net/remote16.png)
1. set the shared key for VPN IKEv2
    * ![set shared key for VPN IKEv2](../../images/net/remote17.png)
1. connect the VPN gateway
    * ![connect VPN gateway](../../images/net/remote18.png)

## Hub ネットワーク内に DNS フォワーダーを構築してオンプレから DB に接続する

1. install DNS role and features
1. right click on DNS and DNS Manager
    * ![image](../../images/net/dnssetup_01.png)
1. right click on Conditional Forwarder and hit on New Conditional Forwarder
    * ![image](../../images/net/dnssetup_02.png)
1. set DNS Domain as 'privatelink.mongo.cosmos.azure.com' if the destination is MongoDB API and set 168.63.129.16 as master server
    * ![image](../../images/net/dnssetup_03.png)
    * [What is IP address 168.63.129.16?](https://learn.microsoft.com/en-us/azure/virtual-network/what-is-ip-address-168-63-129-16)
    * [Azure Private Endpoint DNS configuration](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns)
    * [【AZ-900】Azure DNSとは？DNSの仕組みからわかりやすく解説！](https://az-start.com/azure-dns-overview/)
    * [Azure Private Linkを構成するにあたって注意点は？](https://cloudsteady.jp/post/37510/)
1. connect the private DNS zone with the hub network with Virtual Network Link