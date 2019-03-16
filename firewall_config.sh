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
printf "\n${YELLOW}Note:${NC} This script will remove the courent iptables setting."
printf "\n${YELLOW}Note:${NC} You should disable other firewalls, this script only works with iptables.\n\n"

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
#systemctl start ipset
#systemctl start iptables

# ------------------
# Start to config...
# ------------------

# Create ipset
ipset create iran_ipv4 hash:net
ipset create white_list hash:ip
ipset create block_list hash:ip

# Read CIDR file and add them to ipset
while read line; do
  ipset add iran_ipv4 $line
done < iran_ipv4.txt

# Create firewall ruls
# Empty all rules
iptables -F
iptables -X

# Set default output to accept because of new connections to random hosts
# We don't need forward for softether so drop all
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Create reject chain to proper rejection
iptables -N REJECT_WITH
iptables -A REJECT_WITH -j LOG --log-prefix "Access to ip rejected: "
iptables -A REJECT_WITH -p tcp -j REJECT --reject-with tcp-reset
iptables -A REJECT_WITH -j REJECT --reject-with icmp-port-unreachable

# Create ACL chain to create block list or white list
iptables -N ACCESS_CTRL
iptables -A ACCESS_CTRL -m set --match-set white_list src -j ACCEPT
iptables -A ACCESS_CTRL -j LOG --log-prefix "New connection from: "
iptables -A ACCESS_CTRL -m set --match-set iran_ipv4 src -j SET --add-set white_list src
iptables -A ACCESS_CTRL -m set ! --match-set iran_ipv4 src -j SET --add-set block_list src
iptables -A ACCESS_CTRL -j DROP

# Authorize already established connections, it is important for speed. Allow port 443 22 53 
iptables -A INPUT -i $INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -i $INTERFACE -m set --match-set white_list src -j ACCEPT
iptables -A INPUT -i $INTERFACE -m set --match-set block_list src -j DROP
iptables -A INPUT -i $INTERFACE -p tcp --dport 443 -m state --state NEW -j ACCESS_CTRL 
iptables -A INPUT -i $INTERFACE -p tcp --dport 22  -m state --state NEW -j ACCESS_CTRL 


# remember the output chain policy is accept.
iptables -A OUTPUT -o $INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -o $INTERFACE -m set --match-set block_list dst -j DROP
iptables -A OUTPUT -o $INTERFACE -m state --state NEW -m set --match-set white_list dst -j ACCEPT
iptables -A OUTPUT -o $INTERFACE -m state --state NEW -m set --match-set iran_ipv4 dst -j REJECT_WITH

# enable NTP, it will accept by default rule. no need to set it.
#iptables -A OUTPUT -p udp --dport 123 -j ACCEPT


# Save the firewall setting
service ipset save
service iptables save