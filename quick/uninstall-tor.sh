#!/bin/sh

echo Uninstall installed packages
opkg remove tor-geoip
opkg remove tor
opkg remove lua
opkg remove jq --autoremove

echo Remove directories
rm -rf /opt/lib/lua /opt/etc/rublock /opt/etc/tor

echo Remove scripts
rm /opt/bin/blupdate.lua
rm /opt/bin/rublock.sh

echo Remove ipset modules
sed -i '/modules/d; /modprobe/d' /etc/storage/start_script.sh

echo Clean config iptables
cat /dev/null > /opt/bin/update_iptables.sh

cat >> /opt/bin/update_iptables.sh << 'EOF'
#!/bin/sh
### Custom user script for post-update iptables
### This script auto called after internal firewall restart
### First param is:
###  "start" (call at start optware),
###  "stop" (call before stop optware),
###  "update" (call after internal firewall restart).
### Include you custom rules for iptables below:
case "\$1" in
start|update)
	# add iptables custom rules
	echo "firewall started"
	;;
stop)
	# delete iptables custom rules
	echo "firewall stopped"
	;;
*)
	echo "Usage: \$0 {start|stop|update}"
	exit 1
	;;
esac
EOF

echo Clean dnsmasq
sed -i '/Tor/d; /onion/d; /rublock/d' /etc/storage/dnsmasq/dnsmasq.conf

echo Clean crontab tasks
sed -i '/rublock/d' /etc/storage/cron/crontabs/$USER

echo Reboot
reboot
