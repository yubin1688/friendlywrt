#!/bin/sh

setup_ssid()
{
    local r=$1
    local chip

    if ! uci show wireless.${r} >/dev/null 2>&1; then
        return
    fi

    logger "${TAG}: setup $1's ssid"
    wlan_path=/sys/devices/`uci get wireless.${r}.path`
    wlan_path=`find ${wlan_path} -name wlan* | tail -n 1`
    local mac=`cat ${wlan_path}/address`
    
    local dev_path=/sys/devices/`uci get wireless.${r}.path`
    idVendor=`cat ${dev_path}/../idVendor`
    idProduct=`cat ${dev_path}/../idProduct`
    if [ "x${idVendor}:${idProduct}" = "x0bda:c811" ]; then
        chip="rtl8821cu"
        touch ${FE_DIR}/first_insert_${chip}     # for /etc/hotplug.d/usb/31-usb_wifi
    fi

    uci set wireless.${r}.disabled=0
    if [ -n "${chip}" ];then
        uci set wireless.default_${r}.ssid=${chip}-${mac}
    else
        uci set wireless.default_${r}.ssid=FriendlyWrt-${mac}
    fi
    uci set wireless.default_${r}.encryption=psk2
    uci set wireless.default_${r}.key=password
    uci commit
}

FE_DIR=/root/.friendlyelec/
mkdir -p ${FE_DIR}
TAG=friendlyelec
logger "${TAG}: /root/setup.sh running"

PLATFORM='sun8i|sun50i'
if ! grep -E $PLATFORM /sys/class/sunxi_info/sys_info -q; then
        logger "only support $PLATFORM. exiting..."
        exit 0
fi

BOARD=`grep "board_name" /sys/class/sunxi_info/sys_info`
BOARD=${BOARD#*FriendlyElec }

logger "${TAG}: init for ${BOARD}"
if ls /root/board/${BOARD}/* >/dev/null 2>&1; then
    cp -rf /root/board/${BOARD}/* /
fi

# update /etc/config/network
WAN_IF=`uci get network.wan.ifname`
if [ "x${WAN_IF}" = "xeth0" ]; then
	uci set network.wan.dns=8.8.8.8
	uci commit
fi

# update /etc/config/wireless
for i in `seq 0 1`; do
    setup_ssid radio${i}
done

/etc/init.d/led restart
/etc/init.d/network restart
/etc/init.d/dnsmasq restart

logger "done"