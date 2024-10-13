#!/bin/bash
#
# This file is part of the OpenWrt build process and is called after
# the configuration is loaded.
#
# The script can be used to customize the build process further.

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

# Add custom packages (example)
# echo "CONFIG_PACKAGE_vim=y" >> .config
# echo "CONFIG_PACKAGE_nano=y" >> .config

# Create update_hosts.sh script
mkdir -p files/usr/bin
cat << 'EOF' > files/usr/bin/update_hosts.sh
#!/bin/sh
set -e

CHECK_URL="https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn-social/hosts"
HOSTS_FILE="/etc/hosts"
LAST_DATE_FILE="/etc/last_update_date"
TMP_FILE="/tmp/hosts_tmp"
BAK_FILE="/tmp/hosts.bak"

if ! curl -sSfL "$CHECK_URL" -o "$TMP_FILE"; then
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
    # Backup the old hosts file to /tmp
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
    rm -f "$BAK_FILE"  # Remove backup after successful update
else
    rm -f "$TMP_FILE"
    echo "Hosts file is already up to date"
fi
EOF

chmod +x files/usr/bin/update_hosts.sh

# Add a cron job to update hosts file on the first Monday of each month at 4 AM
mkdir -p files/etc/crontabs
echo "0 4 1-7 * 1 [ $(date +\%d) -le 7 ] && /usr/bin/update_hosts.sh" >> files/etc/crontabs/root

# Customize default IP address for LAN interface
sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate

# Modify default theme (optional)
# sed -i 's/luci-theme-bootstrap/luci-theme-material/g' feeds/luci/collections/luci/Makefile

# Add custom files or configurations
# cp -r $GITHUB_WORKSPACE/custom_files/* files/

# Apply patches
# git apply $GITHUB_WORKSPACE/patches/*.patch

# Customize hostname
sed -i 's/OpenWrt/Linksys02023/g' package/base-files/files/bin/config_generate

# Enable WiFi by default
sed -i 's/option disabled 1/option disabled 0/g' package/kernel/mac80211/files/lib/wifi/mac80211.sh

# Set timezone
sed -i "s/timezone='UTC'/timezone='Europe\/Kiev'/g" package/base-files/files/bin/config_generate

# Add other customizations below

# Print disk usage for debugging
df -h
