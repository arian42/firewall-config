#!/bin/bash
# Config ipv4 firewall for CentOS 7.x by Aryan

# add some color to terminal
RED='\033[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
NC='\033[0m'

# Check for root
if [[ "$EUID" -ne 0 ]]; then
	printf "\n${RED}You need to run this as root${NC}"
	exit 1
fi


printf "\n${YELLOW}Note:${NC} This script only works on CentOS 7.x"
printf "\n      - IF you want to use it on other distros you must install and enable ipset and iptables service to save the config to last after reboot."
printf "\n${YELLOW}Note:${NC} This script will remove the courent iptables setting.\n"
printf "\n${YELLOW}Note:${NC} You should disable other firewalls, this script only works with iptables.\n"
# Ask the user if they want to continue.
until [[ $SET_CONFIG =~ (y|n) ]]; do
  read -rp "Do you want to continue? [y/n]: " -e -i "n" SET_CONFIG
done
if [[ "$SET_CONFIG" == "n" ]]; then
  exit 2
fi

# guess the default public network interface
GUESS_INTERFACE=$(ip link | awk -F: '$0 !~ "lo|vir|wl|^[^0-9]"{print $2;getline}')
ip link
until [[ "$INTERFACE" != "" ]]; do
  read -rp "Enter the public network interface: " -e -i "$GUESS_INTERFACE" INTERFACE
done

# Install ipset and iptables
yum install iptables ipset -y
# Install service that will save config after reboot
yum install iptables-service ipset-service -y

# Enable service for reboot
systemctl enable iptables
systemctl enable ipset

# systemctl [stop|start|restart] iptables
systemctl start ipset
systemctl start iptables

# ------------------
# Start to config...
# ------------------

# Create ipset for iran IPs
#ipset create iran_ipv4 hash:net

# Read CIDR file and add them to ipset
#while read line; do
#  ipset add iran_ipv4 $line
#done < iran_ipv4.txt

# Create firewall ruls
# {
# Empty all rules
iptables -F
iptables -X

# Set default output to accept because of VPN
# We don't need forward for softether so drop all
iptables -P INPUT ACCEPT
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Authorize already established connections. it is important for speed
iptables -A INPUT  -i $INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o $INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT  -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Disable input Ping it also will disable PMTUD. I am not sure about this rule.
#iptables -A INPUT -i $INTERFACE -p icmp -m state --state NEW -j ACCEPT
#iptables -t filter -A INPUT -p icmp -m state --state ESTABLISHED,RELATED -j ACCEPT
#iptables -t filter -A OUTPUT -p icmp -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
#iptables -A OUTPUT -o $INTERFACE -p icmp -j ACCEPT

# Access SSH only from Iran 
#iptables -A INPUT -i $INTERFACE -p tcp --dport 22 -m set --match-set iran_ipv4 src -m state --state new -j ACCEPT
#iptables -A OUTPUT -o $INTERFACE -p tcp --sport 22 -m set --match-set iran_ipv4 dst -m state --state new -j ACCEPT

# With this rule, you only can connect to vpn from iran and no program can start connection to Iran so you can't connect to Iran with vpn
#iptables -A INPUT  -i $INTERFACE -p tcp --dport 443 -m set --match-set iran_ipv4 src -m state --state new -j ACCEPT
#iptables -A INPUT  -i $INTERFACE -p udp --dport 443 -m set --match-set iran_ipv4 src -m state --state new -j ACCEPT
iptables -A OUTPUT -o $INTERFACE -p tcp -m set --match-set iran_ipv4 dst -m state --state new -j REJECT --reject-with icmp-host-prohibited
iptables -A OUTPUT -o $INTERFACE -p udp -m set --match-set iran_ipv4 dst -m state --state new -j REJECT --reject-with icmp-host-prohibited

# enable NTP, it will accept by default rule. no need to set it.
#iptables -A OUTPUT -p udp --dport 123 -j ACCEPT

# Log before dropping
#iptables -A INPUT -j LOG -m limit --limit 12/min --log-level 4 --log-prefix 'IP INPUT drop: '
#iptables -A INPUT -j DROP

# }

# Save the firewall setting
##service ipset save
##service iptables save