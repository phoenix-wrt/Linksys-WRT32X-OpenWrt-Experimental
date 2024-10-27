#!/bin/bash
#
# This file is part of the OpenWrt build process and is called after
# the configuration is loaded.

# 1. Basic compilation settings
#----------------------------------------
# Enable and configure ccache
echo "CONFIG_CCACHE=y" >> .config
echo "CONFIG_CCACHE_DIR=$HOME/.ccache" >> .config

# Optimize ccache
echo "export CCACHE_COMPRESS=1" >> $GITHUB_ENV
echo "export CCACHE_COMPRESSLEVEL=5" >> $GITHUB_ENV
echo "export CCACHE_MAXSIZE=2G" >> $GITHUB_ENV

# Enable parallel build for packages
echo "CONFIG_PKG_BUILD_JOBS=$BUILD_THREADS" >> .config
echo "CONFIG_PKG_BUILD_PARALLEL=y" >> .config

# Optimize for faster compilation
echo "CONFIG_DEVEL=y" >> .config
echo "CONFIG_BUILD_LOG=y" >> .config
echo "CONFIG_CCACHE=y" >> .config
echo "CONFIG_TOOLCHAINOPTS=y" >> .config
echo "CONFIG_GCC_USE_VERSION_9=y" >> .config

# 2. Create file structure and directories
#----------------------------------------
# Create necessary directories
mkdir -p files/usr/bin
mkdir -p files/etc/init.d
mkdir -p files/etc/crontabs
mkdir -p files/etc/dnsmasq.conf.d

# 3. Setup hosts file and related scripts
#----------------------------------------
# Create update_hosts.sh script
cat << 'EOF' > files/usr/bin/update_hosts.sh
#!/bin/sh
set -e

CHECK_URL="https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn-social/hosts"
HOSTS_FILE="/tmp/hosts"
LAST_DATE_FILE="/tmp/last_update_date"
TMP_FILE="/tmp/hosts_tmp"
BAK_FILE="/tmp/hosts.bak"
BOOT_FLAG="/tmp/first_boot"

# Function to download the file
download_file() {
    if command -v wget >/dev/null 2>&1; then
        wget -q -O "$1" "$2"
    elif command -v uclient-fetch >/dev/null 2>&1; then
        uclient-fetch -q -O "$1" "$2"
    else
        echo "Error: Neither wget nor uclient-fetch is available" >&2
        exit 1
    fi
}

# Check if this is first boot
if [ ! -f "$BOOT_FLAG" ]; then
    # First boot after restart - download fresh file
    touch "$BOOT_FLAG"
    if ! download_file "$HOSTS_FILE" "$CHECK_URL"; then
        echo "Failed to download hosts file" >&2
        exit 1
    fi
    
    # Check if the downloaded file is valid
    if [ ! -s "$HOSTS_FILE" ] || ! grep -q "^# Title: StevenBlack/hosts" "$HOSTS_FILE"; then
        echo "Downloaded file is empty or has unexpected format" >&2
        rm -f "$HOSTS_FILE"
        exit 1
    fi

    # Extract and save the date
    sed -n 's/^# Date: //p' "$HOSTS_FILE" > "$LAST_DATE_FILE"
    
    # Restart dnsmasq
    if ! /etc/init.d/dnsmasq restart; then
        echo "Failed to restart dnsmasq" >&2
        rm -f "$HOSTS_FILE"
        exit 1
    fi
    
    echo "Initial hosts file downloaded successfully"
    exit 0
fi

# Normal update check during runtime
if ! download_file "$TMP_FILE" "$CHECK_URL"; then
    echo "Failed to download hosts file" >&2
    exit 1
fi

# Check if the downloaded file is not empty and has the expected format
if [ ! -s "$TMP_FILE" ] || ! grep -q "^# Title: StevenBlack/hosts" "$TMP_FILE"; then
    echo "Downloaded file is empty or has unexpected format" >&2
    rm -f "$TMP_FILE"
    exit 1
fi

NEW_DATE=$(sed -n 's/^# Date: //p' "$TMP_FILE")
[ -f "$LAST_DATE_FILE" ] && LAST_DATE=$(cat "$LAST_DATE_FILE") || LAST_DATE=""

if [ "$NEW_DATE" != "$LAST_DATE" ]; then
    # Backup the old hosts file
    cp "$HOSTS_FILE" "$BAK_FILE"

    # Update the hosts file
    mv "$TMP_FILE" "$HOSTS_FILE"
    echo "$NEW_DATE" > "$LAST_DATE_FILE"

    # Restart dnsmasq
    if ! /etc/init.d/dnsmasq restart; then
        echo "Failed to restart dnsmasq. Reverting changes." >&2
        mv "$BAK_FILE" "$HOSTS_FILE"
        rm -f "$LAST_DATE_FILE"
        exit 1
    fi

    echo "Hosts file updated successfully"
    rm -f "$BAK_FILE"
else
    rm -f "$TMP_FILE"
    echo "Hosts file is already up to date"
fi
EOF

# Create init script
cat << 'EOF' > files/etc/init.d/hosts-init
#!/bin/sh /etc/rc.common

START=19
STOP=90

start() {
    rm -f /tmp/first_boot
    /usr/bin/update_hosts.sh
}

stop() {
    rm -f /tmp/hosts
    rm -f /tmp/last_update_date
    rm -f /tmp/first_boot
}
EOF

# Set permissions
chmod +x files/etc/init.d/hosts-init
chmod +x files/usr/bin/update_hosts.sh

# Create dnsmasq config
cat << 'EOF' > files/etc/dnsmasq.conf.d/hosts.conf
addn-hosts=/tmp/hosts
EOF

# Add cron job for daily updates
echo "0 4 * * * /usr/bin/update_hosts.sh" >> files/etc/crontabs/root

# 4. System parameters configuration
#----------------------------------------
# Customize default IP address
sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate

# Customize hostname
sed -i 's/OpenWrt/Linksys02023/g' package/base-files/files/bin/config_generate

# Enable WiFi by default
sed -i 's/option disabled 1/option disabled 0/g' package/kernel/mac80211/files/lib/wifi/mac80211.sh

# Set timezone
sed -i "s/timezone='UTC'/timezone='Europe\/Kiev'/g" package/base-files/files/bin/config_generate

# 5. Debug information
#----------------------------------------
# Print disk usage for debugging
df -h
