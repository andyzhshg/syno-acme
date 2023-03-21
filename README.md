# syno-acme
通过acme协议更新群晖HTTPS泛域名证书的自动脚本

兔费域名建议使用 ZeroSSL


2022/6/22 更新群晖7.0以上支持，同时更新acme版本采用自动更新，acme经常更新，以后会自动更新最新版 感谢@iihong 


使用方法参见: 

群晖命令版教程：
[https://www.moteta.eu.org/p/%E7%BE%A4%E6%99%96dsm7.0%E5%85%8D%E8%B4%B9%E8%87%AA%E5%8A%A8%E6%9B%B4%E6%96%B0%E8%AF%81%E4%B9%A6-%E5%91%BD%E4%BB%A4%E7%89%88/](https://www.moteta.eu.org/p/%E7%BE%A4%E6%99%96dsm7.0%E5%85%8D%E8%B4%B9%E8%87%AA%E5%8A%A8%E6%9B%B4%E6%96%B0%E8%AF%81%E4%B9%A6-%E5%91%BD%E4%BB%A4%E7%89%88/)

群晖Docker界面版教程：
[https://www.moteta.eu.org/p/%E7%BE%A4%E6%99%96dsm7.0%E5%85%8D%E8%B4%B9%E8%87%AA%E5%8A%A8%E6%9B%B4%E6%96%B0%E8%AF%81%E4%B9%A6-docker%E7%89%88/](https://www.moteta.eu.org/p/%E7%BE%A4%E6%99%96dsm7.0%E5%85%8D%E8%B4%B9%E8%87%AA%E5%8A%A8%E6%9B%B4%E6%96%B0%E8%AF%81%E4%B9%A6-docker%E7%89%88/)



前人参考

[http://www.up4dev.com/2018/05/29/synology-ssl-wildcard-cert-update/](http://www.up4dev.com/2018/05/29/synology-ssl-wildcard-cert-update/)

---
通过设置 CERT_SERVER 为 zerossl 或 letsencrypt 来决定证书服务商
设置为 zerossl 时：必须设置 ACCOUNT_EMAIL，并以 ZeroSSL 提供证书服务更新
设置为 letsencrypt 时：以 Let's Encrypt 提供证书服务更新，如果出现code:60错误，无法建立SSL连接，请升级群辉内置CA机构根证书，下面有方法：


## 方法一：

直接一条SSH命令更新 CA 库

```sh
sudo mv /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt.bak && sudo curl -Lko /etc/ssl/certs/ca-certificates.crt https://curl.se/ca/cacert.pem
```
如果无法链接 https://curl.se/ca/cacert.pem 时，请选用方法二手动翻墙下载并更新

方法二：

1、下载CA机构根证书
下载地址 https://curl.se/ca/cacert.pem
如无法下载请翻墙

2、将 **cacert.pem** 文件上传到群辉某个目录

3、执行以下2条SSH命令更新 CA 库
请替换以下 /volume1/nas/cacert.pem 为你的文件路径地址

```sh
cp /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt.bak
cp /volume1/nas/cacert.pem /etc/ssl/certs/ca-certificates.crt
```

以上方法可以利用 Putty 或 “任务计划 新增 触发的任务 用户定义的脚本” 来执行SSH命令备份和更新根证书
