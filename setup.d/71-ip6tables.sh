#!/usr/bin/env bash

. "$(dirname "$(realpath "${0}")")/library.sh" || { >&2 echo "FATAL: Could not instantiate function library."; exit 1; }

# Setup our blocked list
ip6tables -N BLOCKED

# ICMP echo-request handling
ip6tables -N PING
ip6tables -A PING -p icmp -m icmp --icmp-type 8 -m length --length 1222 -m comment --comment "SSH Knocking" -m recent --set --name ssh_knock --mask 255.255.255.255 --rsource
ip6tables -A PING -m limit --limit 5/sec -j ACCEPT
ip6tables -A PING -j DROP

# ICMP handling
ip6tables -N ICMP_IN
ip6tables -A ICMP_IN -m icmp -p icmp --icmp-type 0  -m conntrack --ctstate RELATED,ESTABLISHED -m addrtype --dst-type LOCAL -m --comment "ICMP Echo Replies permit to local machine only." -j ACCEPT
ip6tables -A ICMP_IN -m icmp -p icmp --icmp-type 43 -m conntrack --ctstate RELATED,ESTABLISHED -m addrtype --dst-type LOCAL -m --comment "Extended Echo Replies permit to local machine only." -j ACCEPT
ip6tables -A ICMP_IN -m icmp -p icmp --icmp-type 3  -m comment --comment "ICMP dest unreach"      -j ACCEPT
ip6tables -A ICMP_IN -m icmp -p icmp --icmp-type 8  -m comment --comment "Echo requests"          -j PING
ip6tables -A ICMP_IN -m icmp -p icmp --icmp-type 42 -m comment --comment "Extended echo requests" -j PING
ip6tables -A ICMP_IN -m icmp -p icmp --icmp-type 11 -m comment --comment "TTL exceeded"           -j ACCEPT
ip6tables -A ICMP_IN -m icmp -p icmp -j DROP

# Clean rejection
ip6tables -N CLEAN_REJECT
ip6tables -A CLEAN_REJECT -m tcp -p tcp -j REJECT --reject-with tcp-reset
ip6tables -A CLEAN_REJECT -m udp -p udp -j REJECT --reject-with icmp-port-unreachable
ip6tables -A CLEAN_REJECT -j REJECT --reject-with icmp-adm-prohibited

# Rejection rate-limiter
ip6tables -N RL_REJECT
ip6tables -A RL_REJECT -m limit --limit 1/sec -j CLEAN_REJECT
ip6tables -A RL_REJECT -j DROP

# SSH
ip6tables -N SSH_IN
ip6tables -A SSH_IN -m recent --rcheck --seconds 60 --name ssh_knock --mask 255.255.255.255 --rsource -j ACCEPT
ip6tables -j RL_REJECT

# Everything that is related or established should be permmited. This is for performance reasons
ip6tables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Accept everything from loopback
ip6tables -A INPUT -i lo+ -j ACCEPT

# SSH
ip6tables -m tcp -p tcp --dport 22 -j SSH_IN

# Call our block-list
ip6tables -A INPUT -j BLOCKED

# Services we provide
ip6tables -m tcp -p tcp --dport 8443 -j ACCEPT
ip6tables -m tcp -p tcp --dport 8080  -j ACCEPT
ip6tables -m tcp -p tcp --dport 465 -j ACCEPT
ip6tables -m tcp -p tcp --dport 25  -j ACCEPT

# Nat port bounces
ip6tables -t nat -A PREROUTING -m tcp -p tcp --dport 80  -j DNAT --to-destination :8080
ip6tables -t nat -A PREROUTING -m tcp -p tcp --dport 443 -j DNAT --to-destination :8443
ip6tables -t nat -A OUTPUT -d $(dig +short futurology.social)/32 -j DNAT --to-destination 127.0.0.1
