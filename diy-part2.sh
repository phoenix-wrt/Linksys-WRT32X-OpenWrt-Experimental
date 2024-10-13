#!/bin/bash

# Add other customizations here

# Create update_hosts.sh
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
echo "update_hosts.sh script added to the firmware"
