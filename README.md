# syno-acme
通过acme协议更新群晖HTTPS泛域名证书的自动脚本(DSM 6.x)，DSM7 请切换dsm7分支

## 更新日志
1、证书服务器默认为 ZeroSSL，如需使用 letsencrypt 请配置 config 文件；
2、使用 ghproxy 文件加速下载服务，便于国内网络环境。
3、更新 acme.sh 版本。
4、支持 BARK 通知。

使用方法参见: [http://www.up4dev.com/2018/05/29/synology-ssl-wildcard-cert-update/](http://www.up4dev.com/2018/05/29/synology-ssl-wildcard-cert-update/)
