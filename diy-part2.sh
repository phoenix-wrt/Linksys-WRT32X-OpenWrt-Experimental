#!/bin/bash

# 1. Basic compilation settings
#----------------------------------------
echo "CONFIG_CCACHE=y" >> .config
echo "CONFIG_CCACHE_DIR=$HOME/.ccache" >> .config
echo "export CCACHE_COMPRESS=1" >> $GITHUB_ENV
echo "export CCACHE_COMPRESSLEVEL=5" >> $GITHUB_ENV
echo "export CCACHE_MAXSIZE=2G" >> $GITHUB_ENV
echo "CONFIG_PKG_BUILD_JOBS=$BUILD_THREADS" >> .config
echo "CONFIG_PKG_BUILD_PARALLEL=y" >> .config
echo "CONFIG_DEVEL=y" >> .config
echo "CONFIG_BUILD_LOG=y" >> .config
echo "CONFIG_CCACHE=y" >> .config
echo "CONFIG_TOOLCHAINOPTS=y" >> .config
echo "CONFIG_GCC_USE_VERSION_9=y" >> .config

# 2. Create directories
#----------------------------------------
mkdir -p files/usr/bin
mkdir -p files/etc/init.d
mkdir -p files/etc/crontabs
mkdir -p files/etc/dnsmasq.conf.d

# 3. Setup hosts file and scripts
#----------------------------------------
cat << 'EOF' > files/usr/bin/update_hosts.sh
#!/bin/sh
set -e

CHECK_URL="https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn-social/hosts"
HOSTS_FILE="/tmp/hosts.block"
LAST_DATE_FILE="/tmp/last_update_date"
TMP_FILE="/tmp/hosts_tmp"
BAK_FILE="/tmp/hosts.bak"
BOOT_FLAG="/tmp/first_boot"

download_file() {
    if command -v wget >/dev/null 2>&1; then
        wget --no-check-certificate -q -O "$1" "$2"
        return $?
    elif command -v uclient-fetch >/dev/null 2>&1; then
        uclient-fetch -q -O "$1" "$2"
        return $?
    fi
    return 1
}

rm -f "$HOSTS_FILE" "$TMP_FILE" "$LAST_DATE_FILE" "$BAK_FILE"

if ! touch /tmp/test_write; then
    exit 1
fi
rm -f /tmp/test_write

if ! download_file "$TMP_FILE" "$CHECK_URL"; then
    exit 1
fi

if [ ! -s "$TMP_FILE" ] || ! grep -q "^# Title: StevenBlack/hosts" "$TMP_FILE"; then
    rm -f "$TMP_FILE"
    exit 1
fi

if ! mv "$TMP_FILE" "$HOSTS_FILE"; then
    exit 1
fi

if [ ! -f "$HOSTS_FILE" ]; then
    exit 1
fi

sed -n 's/^# Date: //p' "$HOSTS_FILE" > "$LAST_DATE_FILE"
touch "$BOOT_FLAG"

if ! /etc/init.d/dnsmasq restart; then
    rm -f "$HOSTS_FILE"
    exit 1
fi
EOF

cat << 'EOF' > files/etc/dnsmasq.conf.d/hosts.conf
addn-hosts=/tmp/hosts.block
domain-needed
bogus-priv
no-resolv
server=8.8.8.8
server=8.8.4.4
EOF

cat << 'EOF' > files/etc/init.d/hosts-init
#!/bin/sh /etc/rc.common

START=99
STOP=10
USE_PROCD=1

start_service() {
    chmod 755 /usr/bin/update_hosts.sh
    chmod 755 /etc/hotplug.d/iface/99-update-hosts
    mkdir -p /etc/dnsmasq.conf.d
    echo "addn-hosts=/tmp/hosts.block" > /etc/dnsmasq.conf.d/hosts.conf
}

stop_service() {
    rm -f /tmp/hosts.block
    rm -f /tmp/last_update_date
    rm -f /tmp/first_boot
}

service_triggers() {
    procd_add_reload_trigger "network"
}
EOF

mkdir -p files/etc/hotplug.d/iface
cat << 'EOF' > files/etc/hotplug.d/iface/99-update-hosts
#!/bin/sh

[ "$ACTION" = "ifup" ] && [ "$INTERFACE" = "wan" ] && {
    for i in $(seq 1 10); do
        if [ -f "/tmp/resolv.conf" ] && grep -q "nameserver" "/tmp/resolv.conf"; then
            break
        fi
        sleep 2
    done
    
    for i in $(seq 1 5); do
        if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
            if [ ! -x /usr/bin/update_hosts.sh ]; then
                chmod 755 /usr/bin/update_hosts.sh
            fi
            /usr/bin/update_hosts.sh
            exit 0
        fi
        sleep 5
    done
}
EOF

chmod 755 files/usr/bin/update_hosts.sh
chmod 755 files/etc/init.d/hosts-init
chmod 755 files/etc/hotplug.d/iface/99-update-hosts

# 4. System configuration
#----------------------------------------
sed -i 's/OpenWrt/Linksys02023/g' package/base-files/files/bin/config_generate
sed -i "s/timezone='UTC'/timezone='Europe\/Kiev'/g" package/base-files/files/bin/config_generate
