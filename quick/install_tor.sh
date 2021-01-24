#!/bin/sh

echo Check update
opkg update && opkg upgrade

echo Install packages
opkg install tor tor-geoip lua jq

echo Make directories
mkdir -p /opt/lib/lua /opt/etc/rublock

echo Download scripts
wget -q -O /opt/lib/lua/ltn12.lua https://raw.githubusercontent.com/diegonehab/luasocket/master/src/ltn12.lua
wget -q -O /opt/bin/blupdate.lua https://raw.githubusercontent.com/blackcofee/rublock-vpn/master/opt/bin/blupdate.lua
wget -q -O /opt/bin/rublock.sh https://raw.githubusercontent.com/blackcofee/rublock-vpn/master/opt/bin/rublock.sh

echo Load ipset modules
modprobe ip_set_hash_net
modprobe xt_set
ipset -N rublock nethash

echo Execute scripts
chmod +x /opt/bin/blupdate.lua /opt/bin/rublock.sh
rublock.sh

echo Make config tor
cat /dev/null > /opt/etc/tor/torrc

cat >> /opt/etc/tor/torrc << 'EOF'
User admin
PidFile /opt/var/run/tor.pid
DataDirectory /opt/var/lib/tor
ExcludeExitNodes {RU},{UA},{AM},{KG}
StrictNodes 1
#SocksPort 127.0.0.1:9050 # Локальный Socks прокси
VirtualAddrNetwork 10.254.0.0/16 # Виртуальные адреса для .onion ресурсов
AutomapHostsOnResolve 1
TransPort 192.168.1.1:9040 # Адрес LAN интерфейса
TransPort 127.0.0.1:9040
DNSPort 127.0.0.1:9053
EOF

echo Parse user and lan ip
sed -i -e 's/admin/'"$USER"'/' -e 's/192.168.1.1/'"$(nvram get lan_ipaddr)"'/' /opt/etc/tor/torrc

echo Add ipset module
cat >> /etc/storage/start_script.sh << 'EOF'

### Load ipset modules
modprobe ip_set_hash_net
modprobe xt_set
EOF

echo Make config iptables
cat /dev/null > /opt/bin/update_iptables.sh

cat >> /opt/bin/update_iptables.sh << 'EOF'
#!/bin/sh

case "$1" in
start|update)
        # add iptables custom rules
        echo "firewall started"
        [ -d '/opt/etc/rublock' ] || exit 0
        # Create new rublock ipset and fill it with IPs from list
        if [ ! -z "$(ipset --swap rublock rublock 2>&1 | grep 'given name does not exist')" ] ; then
                ipset -N rublock nethash
                for IP in $(cat /opt/etc/rublock/rublock.ips) ; do
                        ipset -A rublock $IP
                done
        fi
        iptables -t nat -I PREROUTING -i br0 -p tcp -m set --match-set rublock dst -j REDIRECT --to-ports 9040
        ;;
stop)
        # delete iptables custom rules
        echo "firewall stopped"
        ;;
*)
        echo "Usage: $0 {start|stop|update}"
        exit 1
        ;;
esac
EOF

echo Add entries to dnsmasq
cat >> /etc/storage/dnsmasq/dnsmasq.conf << 'EOF'

### Tor
server=/onion/127.0.0.1#9053
ipset=/onion/rublock
conf-file=/opt/etc/rublock/rublock.dnsmasq
EOF

echo Add crontab tasks
cat >> /etc/storage/cron/crontabs/$USER << 'EOF'
0 5 * * * /opt/bin/rublock.sh
EOF

echo Reboot
reboot
