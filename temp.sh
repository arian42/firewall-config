iptables -F
iptables -X

 
ipset destroy white_list
ipset destroy block_list

ipset create white_list hash:ip
ipset create block_list hash:ip

iptables -N REJECT_WITH
iptables -A REJECT_WITH -j LOG --log-prefix "Access to ip rejected: "
iptables -A REJECT_WITH -p tcp -j REJECT --reject-with tcp-reset
iptables -A REJECT_WITH -j REJECT --reject-with icmp-port-unreachable


iptables -N VPN_INPUT
iptables -A VPN_INPUT -m set --match-set white_list src -j ACCEPT
iptables -A VPN_INPUT -m set --match-set iran_ipv4 src -j SET --add-set white_list src
iptables -A VPN_INPUT -m set ! --match-set iran_ipv4 src -j SET --add-set block_list src
iptables -A VPN_INPUT -j DROP


iptables -A INPUT -i eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -i eth0 -m set --match-set block_list src -j DROP
iptables -A INPUT -i eth0 -p tcp --dport 443 -m state --state NEW -j VPN_INPUT 
iptables -A INPUT -i eth0 -p tcp --dport 53 -m state --state NEW -j VPN_INPUT 
iptables -A INPUT -i eth0 -p tcp --dport 22 -m state --state NEW -j VPN_INPUT 
iptables -A INPUT -i eth0 -p udp --dport 443 -m state --state NEW -j VPN_INPUT 
iptables -A INPUT -i eth0 -p udp --dport 53 -m state --state NEW -j VPN_INPUT 

iptables -A OUTPUT -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -m state --state NEW -m set --match-set white_list src -j ACCEPT
iptables -A OUTPUT -m state --state NEW -m set --match-set iran_ipv4 src -j REJECT_WITH


iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT