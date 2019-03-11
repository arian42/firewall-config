#!/bin/bash
# Config ipv4 firewall for CentOS 7.x by Aryan

# Install ipset and iptables
##yum install iptables ipset -y
# Install service that will save config after reboot
##yum install iptables-service ipset-service -y

# Enable service for reboot
##systemctl enable iptables
##systemctl enable ipset

# systemctl [stop|start|restart] iptables
#systemctl start ipset
#systemctl start iptables

# ------------------
# Start to config...
# ------------------

# Create ipset for iran IPs
ipset create iran_ipv4 hash:net

# Read CIDR file and add them to ipset
while read line; do
  ipset add iran_ipv4 $line
done < iran_ipv4.txt


# Create firewall ruls
# {
# Empty all rules
iptables -F
iptables -X

printf "\e[1;33m debug\e[0m 1"
# Set default output to accept because of VPN
# We don't need forward for softether so drop all
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

printf "\e[1;33m debug\e[0m 2"
# Authorize already established connections. it is important for speed
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

printf "\e[1;33m debug\e[0m 3"
# Disable input Ping it also will disable PMTUD. I am not sure about this rule.
iptables -A INPUT -p icmp -m state --state NEW -j DROP
#iptables -t filter -A INPUT -p icmp -m state --state ESTABLISHED,RELATED -j ACCEPT
#iptables -t filter -A OUTPUT -p icmp -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -p icmp -j ACCEPT

printf "\e[1;33m debug\e[0m 4"
# Access SSH only from Iran 
iptables -A INPUT  -p tcp --dport 22 -m set --match-set iran_ipv4 src --state new -j ACCEPT
iptables -A OUTPUT -p tcp --sport 22 -m set --match-set iran_ipv4 dst --state new -j ACCEPT

# ------ need rethink ------
# Enable DNS
#iptables -t filter -A INPUT -p tcp --dport 53 -j ACCEPT
#iptables -t filter -A INPUT -p udp --dport 53 -j ACCEPT
#iptables -t filter -A OUTPUT -p tcp --dport 53 -j ACCEPT
#iptables -t filter -A OUTPUT -p udp --dport 53 -j ACCEPT

#iptables -A OUTPUT -p udp -d $dnsip --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
#iptables -A INPUT  -p udp -s $dnsip --sport 53 -m state --state ESTABLISHED     -j ACCEPT
#iptables -A OUTPUT -p tcp -d $dnsip --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
#iptables -A INPUT  -p tcp -s $dnsip --sport 53 -m state --state ESTABLISHED     -j ACCEPT

printf "\e[1;33m debug\e[0m 5"
# you only can connect to vpn from iran and no program can start connection to Iran so you can't connect to Iran with vpn
iptables -A INPUT -m set --match-set iran_ipv4 src --state new -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -m set --match-set iran_ipv4 src --state new -p udp --dport 443 -j ACCEPT
iptables -A OUTPUT -m set --match-set iran_ipv4 dst --state new -p tcp -j REJECT --reject-with icmp-host-prohibited
iptables -A OUTPUT -m set --match-set iran_ipv4 dst --state new -p udp -j REJECT --reject-with icmp-host-prohibited

# enable NTP
#iptables -A OUTPUT -p udp --dport 123 -j ACCEPT
# it will accept by default rule. no need to set it.

printf "\e[1;33m debug\e[0m 6"
# Log before dropping
iptables -A INPUT  -j LOG  -m limit --limit 12/min --log-level 4 --log-prefix 'IP INPUT drop: '
iptables -A INPUT -j DROP

# }

# Save the firewall setting
##service ipset save
##service iptables save