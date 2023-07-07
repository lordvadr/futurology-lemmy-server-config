#!/usr/bin/env bash

. "$(dirname "$(realpath "${0}")")/library.sh" || { >&2 echo "FATAL: Could not instantiate function library."; exit 1; }

# Setup our blocked list
iptables -N BLOCKED

# ICMP echo-request handling
iptables -N PING
iptables -A PING -p icmp -m icmp --icmp-type 8 -m length --length 1222 -m comment --comment "SSH Knocking" -m recent --set --name ssh_knock --mask 255.255.255.255 --rsource
iptables -A PING -m limit --limit 5/sec -j ACCEPT
iptables -A PING -j DROP

# ICMP handling
iptables -N ICMP_IN
iptables -A ICMP_IN -m icmp -p icmp --icmp-type 0  -m conntrack --ctstate RELATED,ESTABLISHED -m addrtype --dst-type LOCAL -m --comment "ICMP Echo Replies permit to local machine only." -j ACCEPT
iptables -A ICMP_IN -m icmp -p icmp --icmp-type 43 -m conntrack --ctstate RELATED,ESTABLISHED -m addrtype --dst-type LOCAL -m --comment "Extended Echo Replies permit to local machine only." -j ACCEPT
iptables -A ICMP_IN -m icmp -p icmp --icmp-type 3  -m comment --comment "ICMP dest unreach"      -j ACCEPT
iptables -A ICMP_IN -m icmp -p icmp --icmp-type 8  -m comment --comment "Echo requests"          -j PING
iptables -A ICMP_IN -m icmp -p icmp --icmp-type 42 -m comment --comment "Extended echo requests" -j PING
iptables -A ICMP_IN -m icmp -p icmp --icmp-type 11 -m comment --comment "TTL exceeded"           -j ACCEPT
iptables -A ICMP_IN -m icmp -p icmp -j DROP

# Clean rejection
iptables -N CLEAN_REJECT
iptables -A CLEAN_REJECT -m tcp -p tcp -j REJECT --reject-with tcp-reset
iptables -A CLEAN_REJECT -m udp -p udp -j REJECT --reject-with icmp-port-unreachable
iptables -A CLEAN_REJECT -j REJECT --reject-with icmp-adm-prohibited

# Rejection rate-limiter
iptables -N RL_REJECT
iptables -A RL_REJECT -m limit --limit 1/sec -j CLEAN_REJECT
iptables -A RL_REJECT -j DROP

# SSH
iptables -N SSH_IN
iptables -A SSH_IN -m recent --rcheck --seconds 60 --name ssh_knock --mask 255.255.255.255 --rsource -j ACCEPT
iptables -j RL_REJECT

# Everything that is related or established should be permmited. This is for performance reasons
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Accept everything from loopback
iptables -A INPUT -i lo+ -j ACCEPT

# SSH
iptables -m tcp -p tcp --dport 22 -j SSH_IN

# Call our block-list
iptables -A INPUT -j BLOCKED

# Services we provide
iptables -m tcp -p tcp --dport 443 -j ACCEPT
iptables -m tcp -p tcp --dport 80  -j ACCEPT
iptables -m tcp -p tcp --dport 465 -j ACCEPT
iptables -m tcp -p tcp --dport 25  -j ACCEPT
