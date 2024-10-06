#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# Modify default IP
#sed -i 's/192.168.1.1/192.168.50.5/g' package/base-files/files/bin/config_generate

# Add cron job to run update_hosts.sh every Monday at 4 AM if it doesn't already exist
# Проверяем, существует ли файл, прежде чем пытаться использовать grep или изменять его
if [ -f package/base-files/files/etc/crontabs/root ]; then
    # Ваши существующие команды grep и модификации здесь
    grep -q '0 5 * * 0 echo "Rebooting..." && reboot' package/base-files/files/etc/crontabs/root || echo '0 5 * * 0 echo "Rebooting..." && reboot' >> package/base-files/files/etc/crontabs/root
else
    echo "Предупреждение: файл crontab не найден. Пропускаем модификацию crontab."
fi
