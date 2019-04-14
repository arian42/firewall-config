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
#GUESS_INTERFACE=$(ip link | awk -F: '$0 !~ "lo|vir|wl|^[^0-9]"{print $2;getline}')
#ip link
#until [[ "$INTERFACE" != "" ]]; do
#  read -rp "Enter the public network interface: " -e -i "$GUESS_INTERFACE" INTERFACE
#done

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


# Read CIDR file and add them to ipset
while read line; do
  ipset add iran_ipv4 $line
done < iran_ipv4.txt

# Create firewall ruls
# Empty all rules
iptables -F
iptables -X


# The Gool is to block output to a iran_ipv4 and create a white list form it
# and block ssh attackers, so this is pretty open firewall
iptables -P INPUT ACCEPT
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT


# Create ACL chain to create white list
iptables -N ACL
# This checks if it is alredy in white list
iptables -A ACL -m set --match-set white_list src -j ACCEPT
# This will create a white list
iptables -A ACL -m set --match-set iran_ipv4 src -j SET --add-set white_list src
# Accept other things
iptables -A ACL -j ACCEPT


# Accept all local
iptables -A INPUT -i lo -j ACCEPT
# This roule is for speed up
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
# filter port 22 from attacers 
iptables -A INPUT -p tcp --dport 22  -m set ! --match-set white_list src -j DROP
# We need this for output white list pass
iptables -A INPUT -p tcp --dport 443 -m state --state NEW -j ACL 
# We accept other things


# Accept all local
iptables -A OUTPUT -o lo -j ACCEPT
# This is super important because iran_ipv4 is big list 
iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
# Allow the white list 
iptables -A OUTPUT -m set --match-set white_list dst -j ACCEPT
# Block if it is not in white list and it is in iran_ip
iptables -A OUTPUT -m set --match-set iran_ipv4 dst -j REJECT
# We accept other things


# Save the firewall setting
service ipset save
service iptables save