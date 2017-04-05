# JellyAP - Create a WIFI AP with transparent proxy quickly

[中文版](https://github.com/7sDream/jellyap/blob/master/README.zh.md)

## The name

I love jellyfish.

And it is almost transparent. XD

## Usage

```bash
git clone github.com/7sDream/jellyap
cd jellyap
chmox +x jellyap.sh
./jellyap.sh
```

will let you into a wizard.

![][normal]

Or if you already know what network interface should be used, run this:

```bash
./jellyap.sh eth0 wlan0 NAME PASSWORD no
```

![][normal-no-wizard]

The 5th argument `no` means don't enable shadowsocks relay, you can turn on it by value `yes`

## Enable shadowsocks transparent proxy

With wizard:

![][with-ss]

With arguments:

![][with-ss-no-wizard]

Argument order:

`WAN LAN AP_NAME AP_PASSWORD yes SS_ADDR SS_PORT SS_PASSWORD SS_METHOD SS_LOCAL_PORT`

## Connection test

![][android-connection-test]

You see, just connect the WiFi we create, without any configure or other apps, we already behind a transparent proxy.

Speed depends on your shadowsocks connection and local network quality, in my test, it can run out of all my WAN bandwidth

My test machines:

- Shadowsocks server: 1 CPU, 500M RAM, 1000M Bandwidth, DightalOcean, SGP
- Local shadowsocks client: i7-4500U, 8G RAM, **10M** Bandwidth, TianJin, China
- WiFi client: Oneplus 3, Android 7.1.1, OxygenOS

Result:

![][speed-test]

## Dependencies

- hostapd
- dnsmasq
- nmcli (network-manager)
- rfkill (rfkill)
- ip (iproute2)
- iptables
- shadowsocks-libev (if enable shadowsocks relay, AP as a transparent proxy)
- run as root

## Configure

just open `jellyap.sh`, find the `[User configure]` section(line 24).

read the comment and you know how to configure this script.

## LICENSE

MIT.


[normal]: http://rikka-10066868.image.myqcloud.com/1f0d8f22-4d3b-4023-bcdb-f17c1ba348aa.gif
[with-ss]: http://rikka-10066868.image.myqcloud.com/1a3e6dae-03b0-47c2-8bbf-e6c8df1e1862.gif
[normal-no-wizard]: http://rikka-10066868.image.myqcloud.com/21be867f-f5ad-4e62-9aba-50232a677df3.gif
[with-ss-no-wizard]: http://rikka-10066868.image.myqcloud.com/497105c4-43a9-4279-9070-3397e0b7c374.gif
[android-connection-test]: http://rikka-10066868.image.myqcloud.com/c982f4c8-fafb-4f49-bc32-31b61d9ffe3b.gif
[speed-test]: http://rikka-10066868.image.myqcloud.com/cb8f9b31-4a6c-49ba-94ec-491e430af74e.gif
