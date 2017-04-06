#!/usr/bin/env bash

# Effect: Create a Wifi AP with transparent shadowsocks relay in debian based system;
# Author: 7sDream

# Dependencies:
#   - hostapd & dnsmasq & nmcli & rfkill & & iptables & iproute2 is installed
#   - A wireless network card suppose AP mode, and doesn't connect to any AP now
#   - If you want shadowsocks relay, shadowsocks-libev needs to be installed
#   - Run as root

# Changelog:
#   - 2015.03.07:
#       - Fitst version, basic functional.
#   - 2016.02.28:
#       - Chang SheBang.
#       - User can interactively change interface, ssid and password 
#         without edit conf files.
#   - 2017.01.17:
#       - Fix some bug with `read` command after system upgrade.
#   - 2017.04.05
#       - Add shadowsocks relay(include udp relay)

# ===== [User configure] ====

# The interface that already has internet access, 
# in most cases it will be a ethernet interface, like eth0 or enp1s0
# If empty, will read from $1 or the wizard.
WAN_INTERFACE=""

# The interface that used to create AP, 
# in most cases it will be a wireless interface, like wlan0 or wlp2s0
# If empty, will read from $2 or the wizard.
LAN_INTERFACE=""

# AP SSID, if empty, will read from $3 or the wizard
AP_NAME=""

# AP PASSWORD, if empty, will read from $4 or the wizard
PASSWORD=""

# AP as a transparent proxy, use shadowsocks relay
# value can be yes/no
# if empty, read from $5 or the wizard.
ENABLE_SS_RELAY=""

# ONLY work when ENABLE_SS_RELAY = yes
SS_SERVER_ADDR=""       # Shadowsocks server address $6
SS_SERVER_PORT=""       # Shadowsocks server port $7
SS_PASSWORD=""          # Shadowsocks server password $8
SS_METHOD=""            # Shadowsocks encryption method $9
SS_LOCAL_PORT="12345"   # ss-redir local port $10
SS_TIMEOUT="600"        # shadowsocks timeout
SS_FAST_OPEN="false"    # Use TCP fast open?
# =====

# Show configure to user, wait for a comfirm
NEED_CONFIRM=1

DHCP_ROUTER_IP="192.168.43.1"
DHCP_RANGE_MIN="192.168.43.2"
DHCP_RANGE_MAX="192.168.43.10"

# DNSPod DNS
DNS_1="119.29.29.29"

# Google DNS
DNS_2="8.8.8.8"

# Other alternative DNS

# Alibaba DNS
# DNS_1="223.5.5.5"
# DNS_2="223.6.6.6"

# USTC LUG DNS
# 202.38.64.1       (USTC LUG)
# 202.38.93.153     (USTC LUG Education)
# 202.141.176.93    (USTC LUG China Mobile)
# 202.141.162.123   (USTC LUG China Telecom)

# ===== End of [User configure] ====

# ===== [CONST] =====
SCRIPTPATH=$(dirname $0)
IPTABLES_CHAIN_NAME="SHADOWSOCKS"
FWMARK="0x01/0x01"
IPROUTE2_TABLEID=100

read -d '' SS_CONF_TEMPLATE << EOF
{
    "server": "{SS_SERVER_ADDR}",
    "server_port": {SS_SERVER_PORT},
    "local_address": "0.0.0.0",
    "local_port": {SS_LOCAL_PORT},
    "password": "{SS_PASSWORD}",
    "timeout": {SS_TIMEOUT},
    "method": "{SS_METHOD}",
    "fast_open": {SS_FAST_OPEN}
}
EOF

read -d '' DNSMASQ_CONF_TEMPLATE << EOF
interface={LAN_INTERFACE}
bind-interfaces
dhcp-range={DHCP_RANGE_MIN},{DHCP_RANGE_MAX}
dhcp-option=option:router,{DHCP_ROUTER_IP}
dhcp-option=option:dns-server,{DHCP_ROUTER_IP}
no-resolv
no-poll
server={DNS_1}
server={DNS_2}
EOF

read -d '' HOSTAPD_CONF_TEMPLATE << EOF
interface={LAN_INTERFACE}
driver=nl80211
ssid={SSID}
hw_mode=g
channel=6
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase={PASSWORD}
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

RED='\033[0;31m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'
# ===== End of [CONST] =====

# ===== [Function define] =====
function error() {
    echo -e -n "${RED}ERROR!${NC}: "
    echo -e $1
    exit 1
}

function command_test() {
    # Test if the [$1: command] exist in system.
    # If not exist, tell user to install [$2: the package].

    if [ -n "$2" ]; then PACKAGE="$2"; else PACKAGE="$1"; fi

    if [ -z "$(which $1)" ]; then
        error "Command [$1] not exist, please install package [$PACKAGE]."
    fi
}

function input_string() {
    # Get a string from user with [$1: prompt string],
    # make sure the length of string greate(or equal) then [$2: min length]
    # and less then [$3: max length].

    PROMPT="Please input a string:"
    MIN_LENGTH=0
    MAX_LENGTH=80

    if [ -n "$1" ]; then PROMPT="$1"; fi
    if [ -n "$2" ]; then MIN_LENGTH="$2"; fi
    if [ -n "$3" ]; then MAX_LENGTH="$3"; fi

    read -p "$PROMPT" val

    until [ ${#val} -ge ${MIN_LENGTH} ] && [ ${#val} -lt ${MAX_LENGTH} ]; do
        read -p "$(echo -e "${RED}!!Invalid!!${NC} $PROMPT")" val
    done

    echo "$val"
}

function input_integer() {
    # Get a integer from user with [$1: prompt string],
    # make sure the integer greate(or equal) then [$2: min value]
    # and less then [$3: max value].

    PROMPT="Please input a integer:"
    MIN_INTEGER=0
    MAX_INTEGER=100000000

    if [ -n "$1" ]; then PROMPT="$1"; fi
    if [ -n "$2" ]; then MIN_INTEGER="$2"; fi
    if [ -n "$3" ]; then MAX_INTEGER="$3"; fi

    RE_INT=^[0-9]+$ # integer regex

    read -p "$PROMPT" val

    until [[ "$val" =~ ${RE_INT} ]] && \
    [ $val -ge ${MIN_INTEGER} ] && \
    [ $val -lt ${MAX_INTEGER} ]; do
        read -p "$(echo -e "${RED}!!Invalid!!${NC} $PROMPT")" val
    done

    echo "$val"
}

function iptables_chain_bypass_LAN() {
    # Add rule to iptables [$1: table] [$2: chain] to bypass LAN addresses.

    iptables -t $1 -A $2 -d 0.0.0.0/8 -j RETURN
    iptables -t $1 -A $2 -d 10.0.0.0/8 -j RETURN
    iptables -t $1 -A $2 -d 127.0.0.0/8 -j RETURN
    iptables -t $1 -A $2 -d 169.254.0.0/16 -j RETURN
    iptables -t $1 -A $2 -d 172.16.0.0/12 -j RETURN
    iptables -t $1 -A $2 -d 192.168.0.0/16 -j RETURN
    iptables -t $1 -A $2 -d 224.0.0.0/4 -j RETURN
    iptables -t $1 -A $2 -d 240.0.0.0/4 -j RETURN
}

function clean_envirment() {

    killall dnsmasq
    killall hostapd

    if [ "$ENABLE_SS_RELAY" = "yes" ]; then
        kill -9 $(cat ss-redir.pid)
    fi

    # Delete NAT Setting
    iptables -t nat -F

    # Delete SS relay rules
    if [ "$ENABLE_SS_RELAY" = "yes" ]; then
        iptables -t nat -X $IPTABLES_CHAIN_NAME1
        iptables -t mangle -F
        iptables -t mangle -X $IPTABLES_CHAIN_NAME
        ip rule del fwmark $FWMARK
        ip route flush table $IPROUTE2_TABLEID
    fi

    # Disable ip forward
    sysctl net.ipv4.ip_forward=0

    # Start wlan
    nmcli r wifi on

    # Delete temp configure files
    rm dnsmasq.conf hostapd.conf
    if [ "$ENABLE_SS_RELAY" = "yes" ]; then
        rm ss-redir.conf ss-redir.pid
    fi
}

# ===== End of [function define] =====

# ===== [Prepare for work] =====
# Make sure run as root before running
(( EUID != 0 )) && exec sudo -- "$0" "$@"

# clean command
if [ "$1" = "clean" ]; then 
    clean_envirment
    exit 0
fi

if [ -n "$1" ]; then WAN_INTERFACE="$1"; fi
if [ -n "$2" ]; then LAN_INTERFACE="$2"; fi
if [ -n "$3" ]; then AP_NAME="$3"; fi
if [ -n "$4" ]; then PASSWORD="$4"; fi
if [ -n "$5" ]; then ENABLE_SS_RELAY="$5"; fi
if [ -n "$6" ]; then SS_SERVER_ADDR="$6"; fi
if [ -n "$7" ]; then SS_SERVER_PORT="$7"; fi
if [ -n "$8" ]; then SS_PASSWORD="$8"; fi
if [ -n "$9" ]; then SS_METHOD="$9"; fi
if [ -n "$10" ]; then SS_LOCAL_PORT="${10}"; fi

# check dependencies
command_test "dnsmasq"
command_test "hostapd"
command_test "nmcli" "network-manager"
command_test "ip" "iproute2"
command_test "rfkill"
command_test "iptables"

# cd to curtrent dir, make sure configure files can be read
cd "$SCRIPTPATH"
# ===== End of [prepare fo work] =====

# ===== [Interface configuration] =====
# Get network interface list
IFS=$'\n' read -r -a interfaces -d '' <<< "$(ip link show | sed -rn 's/^[0-9]+: ((\w|\d)+):.*/\1/p')"

if [ -z "$WAN_INTERFACE" ] || [ -z "$LAN_INTERFACE" ]; then
    # Print network interface list
    for i in ${!interfaces[@]}; do echo -e "$i: ${BLUE}${interfaces[$i]}${NC}"; done
    interface_count=${#interfaces[@]}
    # Set WAN interface name
    if [ -z "$WAN_INTERFACE" ]; then
        idx="$(input_integer "Input index of your WAN interfaces name: " 0 $interface_count)"
        WAN_INTERFACE=${interfaces[$idx]}
    fi
    # Set LAN interface name
    if [ -z "$LAN_INTERFACE" ]; then
        idx="$(input_integer "Input index of your LAN interfaces name: " 0 $interface_count)"
        LAN_INTERFACE=${interfaces[$idx]}
    fi
else
    if [ $(echo ${interfaces[@]} | grep "$WAN_INTERFACE" | wc -l) -ne 1 ]; then
        error "No interface named $WAN_INTERFACE."
    fi
    if [ $(echo ${interfaces[@]} | grep "$LAN_INTERFACE" | wc -l) -ne 1 ]; then
        error "No interface named $LAN_INTERFACE."
    fi
fi

if [ -z "$AP_NAME" ]; then
    AP_NAME=$(input_string "Input your AP name (default \"$(hostname) WiFi\"): " 0)
    if [ -z "$AP_NAME" ]; then AP_NAME="$(hostname) WiFi"; fi
fi

if [ -z "$PASSWORD" ] || [ ${#PASSWORD} -lt 8 ]; then
    PASSWORD=$(input_string "Input your AP password (8 chars at least): " 8)
fi

if [ -z $ENABLE_SS_RELAY ] || \
([ "$ENABLE_SS_RELAY" != "yes" ] && [ "$ENABLE_SS_RELAY" != "no" ]); then
    until [ "$ENABLE_SS_RELAY" = "yes" ] || [ "$ENABLE_SS_RELAY" = "no" ]; do
        read -p "Enable shadowsocks relay (yes/no): " ENABLE_SS_RELAY
    done
fi

if [ "$ENABLE_SS_RELAY" = "yes" ]; then
    command_test "ss-redir" "shadowsocks-libev"
fi

if [ "$ENABLE_SS_RELAY" = "yes" ]; then
    if [ -z "$SS_SERVER_ADDR" ]; then
        SS_SERVER_ADDR=$(input_string "Input your shadowsocks server address: " 1)
    fi
    if [ -z "$SS_SERVER_PORT" ]; then
        SS_SERVER_PORT=$(input_integer "Input your shadowsocks server port: " 1 65536)
    fi
    if [ -z "$SS_PASSWORD" ]; then
        SS_PASSWORD=$(input_string "Input your shadowsocks server password: " 1)
    fi
    if [ -z "$SS_METHOD" ]; then
        SS_METHOD=$(input_string "Input your shadowsocks encryption method(default aes-256-cfb): " 0)
        if [ -z "$SS_METHOD" ]; then SS_METHOD="aes-256-cfb"; fi
    fi
    if [ -z "$SS_LOCAL_PORT" ]; then
        SS_LOCAL_PORT=$(input_integer "Input your shadowsocks local port: " 0 65536)
    fi
fi
# ===== End of [Interface configuration] =====

# ===== [Confirm] =====
if [ $NEED_CONFIRM -gt 0 ]; then
    clear

    echo -e "Your wifi AP configure: "
    echo -e "  - AP:"
    echo -e "    - SSID: ${GREEN}$AP_NAME${NC}"
    echo -e "    - PASSWROD: ${RED}$PASSWORD${NC}"
    echo -e "    - WAN: ${BLUE}$WAN_INTERFACE${NC}"
    echo -e "    - LAN: ${BLUE}$LAN_INTERFACE${NC}"
    echo -e "  - DHCP:"
    echo -e "    - ROUTER: $DHCP_ROUTER_IP"
    echo -e "    - RANGE: $DHCP_RANGE_MIN - $DHCP_RANGE_MAX"
    echo -e "    - DNS: $DNS_1, $DNS_2"

    if [ "$ENABLE_SS_RELAY" = "yes" ]; then
        echo -e "  - SS RELAY: ${GREEN}yes${NC}"
        echo -e "    - SERVER: ${GREEN}$SS_SERVER_ADDR${NC}, ${GREEN}$SS_SERVER_PORT${NC}"
        echo -e "    - PASSWORD: ${RED}$SS_PASSWORD${NC}"
        echo -e "    - METHOD: ${GREEN}$SS_METHOD${NC}"
        echo -e "    - LOCAL: 0.0.0.0, $SS_LOCAL_PORT"
        echo -e "    - TIMEOUT: $SS_TIMEOUT"
        echo -e "    - FAST OPEN: $SS_FAST_OPEN"
    else
        echo -e "  - SS RELAY: ${RED}no${NC}"
    fi

    echo

    read -n 1 -p "Please Confirm your configure, Enter to continue, Ctrl-C to exit."
    clear
fi
# ===== End of [Confirm] =====

echo -e "\n===== Creating WiFi AP... =====\n"

# ===== [Clean up environment] =====
# Turn down services
service dnsmasq stop
service hostapd stop

# Kill old processes
killall dnsmasq
killall hostapd

# Restart wlan interface
nmcli r wifi off
rfkill unblock wlan
ifconfig $LAN_INTERFACE up

# Set wlan ip address
ifconfig $LAN_INTERFACE $DHCP_ROUTER_IP
# ===== End of [Clean up environment] =====

# ===== [Configure NAT] =====
# Enable ip forwoad
sysctl net.ipv4.ip_forward=1

# Delete NAT rules
iptables -t nat -F

# Add NAT rule for normal
iptables -P FORWARD ACCEPT
iptables -t nat -A POSTROUTING -o $WAN_INTERFACE -j MASQUERADE
# ===== End of [Configure NAT] =====

# ===== [Configure shadowsocks relay] =====
if [ "$ENABLE_SS_RELAY" = "yes" ]; then
    # Add TCP relay
    iptables -t nat -N $IPTABLES_CHAIN_NAME
    # Shadowsocks bypass self address
    iptables -t nat -A $IPTABLES_CHAIN_NAME -d $SS_SERVER_ADDR -j RETURN
    # Shadowsocks bypass LANs and some other reserved addresses
    iptables_chain_bypass_LAN nat $IPTABLES_CHAIN_NAME
    # Other address relay to shadowsocks
    iptables -t nat -A $IPTABLES_CHAIN_NAME -p tcp -j REDIRECT --to-ports $SS_LOCAL_PORT
    iptables -t nat -A PREROUTING -p tcp -j $IPTABLES_CHAIN_NAME

    # Enable UDP relay
    ip rule add fwmark $FWMARK table $IPROUTE2_TABLEID
    ip route add local 0.0.0.0/0 dev lo table $IPROUTE2_TABLEID
    iptables -t mangle -N $IPTABLES_CHAIN_NAME
    # Shadowsocks bypass LANs and some other reserved addresses
    iptables_chain_bypass_LAN mangle $IPTABLES_CHAIN_NAME
    # Other address relay to shadowsocks
    iptables -t mangle -A $IPTABLES_CHAIN_NAME -p udp -j TPROXY --on-port $SS_LOCAL_PORT --tproxy-mark $FWMARK
    iptables -t mangle -A PREROUTING -j $IPTABLES_CHAIN_NAME
fi
# ===== End of [Configure shadowsocks relay] =====

# ===== [Gen configure files] =====
echo "$DNSMASQ_CONF_TEMPLATE" | sed \
    -e "s/{LAN_INTERFACE}/$LAN_INTERFACE/" \
    -e "s/{DHCP_ROUTER_IP}/$DHCP_ROUTER_IP/" \
    -e "s/{DHCP_RANGE_MIN}/$DHCP_RANGE_MIN/" \
    -e "s/{DHCP_RANGE_MAX}/$DHCP_RANGE_MAX/" \
    -e "s/{DNS_1}/$DNS_1/" \
    -e "s/{DNS_2}/$DNS_2/" \
    > dnsmasq.conf

echo "$HOSTAPD_CONF_TEMPLATE" | sed \
    -e "s/{LAN_INTERFACE}/$LAN_INTERFACE/" \
    -e "s/{PASSWORD}/$PASSWORD/" \
    -e "s/{SSID}/$AP_NAME/" \
    > hostapd.conf

if [ "$ENABLE_SS_RELAY" = "yes" ]; then
    echo "$SS_CONF_TEMPLATE" | sed \
        -e "s/{SS_SERVER_ADDR}/$SS_SERVER_ADDR/" \
        -e "s/{SS_SERVER_PORT}/$SS_SERVER_PORT/" \
        -e "s/{SS_PASSWORD}/$SS_PASSWORD/" \
        -e "s/{SS_LOCAL_PORT}/$SS_LOCAL_PORT/" \
        -e "s/{SS_METHOD}/$SS_METHOD/" \
        -e "s/{SS_TIMEOUT}/$SS_TIMEOUT/" \
        -e "s/{SS_FAST_OPEN}/$SS_FAST_OPEN/" \
        > ss-redir.conf
fi
# ===== End of [Gen configure files] =====

# ===== [Start services] =====
if [ "$ENABLE_SS_RELAY" = "yes" ]; then
    ss-redir -c ss-redir.conf -u -f ss-redir.pid &
fi

dnsmasq -C dnsmasq.conf
hostapd hostapd.conf

# !! Waiting for a <Ctrl+C> here !!
# ===== End of [Start services] =====

echo -e "\nWiFi Stop, Cleaning......\n"

# ===== [Stop Services] =====
# hostapd stopped by Ctrl+C

clean_envirment
# ===== End of [Clean up environment] =====

echo -e "\nDone!\n"
