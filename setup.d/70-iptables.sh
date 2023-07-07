#!/usr/bin/env bash

. "$(dirname "$(realpath "${0}")")/library.sh" || { >&2 echo "FATAL: Could not instantiate function library."; exit 1; }

# Accept all traffic first to avoid ssh lockdown  via iptables firewall rules #
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# Flush All Iptables Chains/Firewall rules #
iptables -F

# Delete all Iptables Chains #
iptables -X

# Flush all counters too #
iptables -Z
# Flush and delete all nat and  mangle #
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -t raw -F
iptables -t raw -X

# Setup our blocked list
iptables -N BLOCKED || true

# ICMP echo-request handling
iptables -N PING || true
iptables -A PING -p icmp -m icmp --icmp-type 8 -m length --length 1222 -m comment --comment "SSH Knocking" -m recent --set --name ssh_knock --mask 255.255.255.255 --rsource
iptables -A PING -m limit --limit 5/sec -j ACCEPT
iptables -A PING -j DROP

# ICMP handling
iptables -N ICMP_IN || true
iptables -A ICMP_IN -m icmp -p icmp --icmp-type 0  -m conntrack --ctstate RELATED,ESTABLISHED -m addrtype --dst-type LOCAL -m comment --comment "ICMP Echo Replies permit to local machine only." -j ACCEPT
iptables -A ICMP_IN -m icmp -p icmp --icmp-type 43 -m conntrack --ctstate RELATED,ESTABLISHED -m addrtype --dst-type LOCAL -m comment --comment "Extended Echo Replies permit to local machine only." -j ACCEPT
iptables -A ICMP_IN -m icmp -p icmp --icmp-type 3  -m comment --comment "ICMP dest unreach"      -j ACCEPT
iptables -A ICMP_IN -m icmp -p icmp --icmp-type 8  -m comment --comment "Echo requests"          -j PING
iptables -A ICMP_IN -m icmp -p icmp --icmp-type 42 -m comment --comment "Extended echo requests" -j PING
iptables -A ICMP_IN -m icmp -p icmp --icmp-type 11 -m comment --comment "TTL exceeded"           -j ACCEPT
iptables -A ICMP_IN -j DROP

# Clean rejection
iptables -N CLEAN_REJECT || true
iptables -A CLEAN_REJECT -m tcp -p tcp -j REJECT --reject-with tcp-reset
iptables -A CLEAN_REJECT -m udp -p udp -j REJECT --reject-with icmp-port-unreachable
iptables -A CLEAN_REJECT -j REJECT --reject-with icmp-admin-prohibited

# Rejection rate-limiter
iptables -N RL_REJECT || true
iptables -A RL_REJECT -m limit --limit 1/sec -j CLEAN_REJECT
iptables -A RL_REJECT -j DROP

# SSH
iptables -N SSH_IN
iptables -A SSH_IN -m recent --rcheck --seconds 60 --name ssh_knock --mask 255.255.255.255 --rsource -j ACCEPT
iptables -A SSH_IN -j RL_REJECT

# Everything that is related or established should be permmited. This is for performance reasons
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Accept everything from loopback
iptables -A INPUT -i lo+ -j ACCEPT

# SSH
iptables -A INPUT -m tcp -p tcp --dport 22 -j SSH_IN

# Call our block-list
iptables -A INPUT -j BLOCKED

# Services we provide
iptables -A INPUT -m tcp -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -m tcp -p tcp --dport 80  -j ACCEPT
iptables -A INPUT -m tcp -p tcp --dport 465 -j ACCEPT
iptables -A INPUT -m tcp -p tcp --dport 25  -j ACCEPT


# Nat rules
iptables -t nat -A PREROUTING -m tcp -p tcp --dport 80  -j DNAT --to-destination :8080
iptables -t nat -A PREROUTING -m tcp -p tcp --dport 443 -j DNAT --to-destination :8443
iptables -t nat -A OUTPUT -d $(dig +short futurology.social)/32 -j DNAT --to-destination 127.0.0.1
