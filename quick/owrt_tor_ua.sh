#!/bin/sh

echo update packages
opkg update

echo Make directories
mkdir -p /etc/rublock

echo install dependes
opkg remove dnsmasq
opkg install dnsmasq-full ipset iptables jq tor tor-geoip
wget -O /bin/uablock.sh https://raw.githubusercontent.com/blackcofee/rublock-shadowsocks/master/owrt/bin/uablock.sh
ipset -N rublock nethash

echo execute script
chmod +x /bin/uablock.sh
uablock.sh

echo Make config tor
cat /dev/null > /etc/tor/torrc

cat >> /etc/tor/torrc << 'EOF'
User tor
DataDirectory /var/lib/tor
ExcludeExitNodes {RU},{UA},{AM},{KG}
StrictNodes 1
#SocksPort 127.0.0.1:9050
VirtualAddrNetwork 10.254.0.0/16
AutomapHostsOnResolve 1
TransPort 192.168.1.1:9040
TransPort 127.0.0.1:9040
DNSPort 127.0.0.1:9053
EOF

echo Make autostart script
cat >> /etc/init.d/update_iptables << 'EOF'
#!/bin/sh /etc/rc.common
START=24
start() {
        # add iptables custom rules
        echo "firewall started"
        [ -d '/etc/rublock' ] || exit 0
        # Create new rublock ipset and fill it with IPs from list
        if [ ! -z "$(ipset --swap rublock rublock 2>&1 | grep 'given name does not exist')" ] ; then
                ipset -N rublock nethash
                for IP in $(cat /etc/rublock/rublock.ips) ; do
                        ipset -A rublock $IP
                done
        fi
        iptables -t nat -I PREROUTING -i br-lan -p tcp -m set --match-set rublock dst -j REDIRECT --to-ports 9040
}
stop() {
        # delete iptables rules
        ipset flush rublock
}
EOF

chmod +x /etc/init.d/update_iptables
/etc/init.d/update_iptables enable

echo Add entries to dnsmasq
cat >> /etc/dnsmasq.conf << 'EOF'

### Tor
server=/onion/127.0.0.1#9053
ipset=/onion/rublock
conf-file=/etc/rublock/rublock.dnsmasq
EOF

echo Reboot
reboot
