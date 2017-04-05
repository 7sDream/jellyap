# JellyAP - 一键创建透明代理的 WiFi 热点

## 关于项目名

因为我喜欢水母（jellyfish）。

而且它也挺透明的。 XD

## 用法

```bash
git clone https://github.com/7sDream/jellyap.git
cd jellyap
chmox +x jellyap.sh
./jellyap.sh
```

直接执行的话会进入向导模式。

![][normal]

如果你已经知道网卡名称，也可以在参数里提供：

```bash
./jellyap.sh eth0 wlan0 NAME PASSWORD no
```

![][normal_no_wizard]

第五个参数 `no` 表示不开启透明代理模式，如果你想打开它，就用 `yes`。

## 开启 shadowsocks 透明代理

向导模式，直接执行就好：

![][with_ss]

直接提供参数：

![][with_ss_no_wizard]

参数按以下顺序提供：

`WAN LAN AP_NAME AP_PASSWORD yes SS_ADDR SS_PORT SS_PASSWORD SS_METHOD SS_LOCAL_PORT`

## 连接测试

![][Android_connection_test]

只要连上 WiFi，然后无需任何配置，我们的流量就全都经过透明代理了。

网速取决于你的 shadowsocks 连接质量和当地网络环境，在我的测试中它能跑满外网带宽。

我的测试环境：

- Shadowsocks 服务器: 1 CPU, 500M RAM, 1000M 带宽, DightalOcean, SGP
- 本地 shadowsocks 客户端: i7-4500U, 8G RAM, **10M** 带宽, 天津
- WiFi 客户端: 一加 3, Android 7.1.1, 氧 OS

结果：

![][speed-test]


## 依赖

- hostapd
- dnsmasq
- nmcli (network-manager)
- rfkill (rfkill)
- ip (iproute2)
- iptables
- shadowsocks-libev （开启透明代理功能时才需要）
- run as root

## 自定义配置

打开 `jellyap.sh`, 找到 `[User configure]` 这一部分（从 24 行开始）。

然后看着注释你就知道要怎么改了。

## LICENSE

MIT.


[normal]: http://rikka-10066868.image.myqcloud.com/1f0d8f22-4d3b-4023-bcdb-f17c1ba348aa.gif
[with_ss]: http://rikka-10066868.image.myqcloud.com/1a3e6dae-03b0-47c2-8bbf-e6c8df1e1862.gif
[normal_no_wizard]: http://rikka-10066868.image.myqcloud.com/21be867f-f5ad-4e62-9aba-50232a677df3.gif
[with_ss_no_wizard]: http://rikka-10066868.image.myqcloud.com/497105c4-43a9-4279-9070-3397e0b7c374.gif
[Android_connection_test]: http://rikka-10066868.image.myqcloud.com/c982f4c8-fafb-4f49-bc32-31b61d9ffe3b.gif
[speed-test]: http://rikka-10066868.image.myqcloud.com/cb8f9b31-4a6c-49ba-94ec-491e430af74e.gif
