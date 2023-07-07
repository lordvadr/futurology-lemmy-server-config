#!/usr/bin/env bash

. "$(dirname "$(realpath "${0}")")/library.sh" || { >&2 echo "FATAL: Could not instantiate function library."; exit 1; }

# Setup our blocked list
ip6tables -N BLOCKED || true

# ICMP echo-request handling
ip6tables -N PING || true
ip6tables -A PING -p ipv6-icmp -m icmp6 --icmpv6-type 8 -m length --length 1222 -m comment --comment 'SSH Knocking' -m recent --set --name ssh_knock --rsource --mask ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff
ip6tables -A PING -m limit --limit 5/sec -j ACCEPT
ip6tables -A PING -j DROP

# ICMP handling
ip6tables -N ICMP_IN || true
ip6tables -A ICMP_IN -m icmp6 -p ipv6-icmp --icmpv6-type 0  -m conntrack --ctstate RELATED,ESTABLISHED -m addrtype --dst-type LOCAL -m comment --comment "ICMP Echo Replies permit to local machine only." -j ACCEPT
ip6tables -A ICMP_IN -m icmp6 -p ipv6-icmp --icmpv6-type 43 -m conntrack --ctstate RELATED,ESTABLISHED -m addrtype --dst-type LOCAL -m comment --comment "Extended Echo Replies permit to local machine only." -j ACCEPT
ip6tables -A ICMP_IN -m icmp6 -p ipv6-icmp --icmpv6-type 3  -m comment --comment "ICMP dest unreach"      -j ACCEPT
ip6tables -A ICMP_IN -m icmp6 -p ipv6-icmp --icmpv6-type 8  -m comment --comment "Echo requests"          -j PING
ip6tables -A ICMP_IN -m icmp6 -p ipv6-icmp --icmpv6-type 42 -m comment --comment "Extended echo requests" -j PING
ip6tables -A ICMP_IN -m icmp6 -p ipv6-icmp --icmpv6-type 11 -m comment --comment "TTL exceeded"           -j ACCEPT
ip6tables -A ICMP_IN -j DROP

# Clean rejection
ip6tables -N CLEAN_REJECT || true
ip6tables -A CLEAN_REJECT -m tcp -p tcp -j REJECT --reject-with tcp-reset
ip6tables -A CLEAN_REJECT -m udp -p udp -j REJECT --reject-with icmp6-port-unreachable
ip6tables -A CLEAN_REJECT -j REJECT --reject-with icmp6-adm-prohibited

# Rejection rate-limiter
ip6tables -N RL_REJECT || true
ip6tables -A RL_REJECT -m limit --limit 1/sec -j CLEAN_REJECT
ip6tables -A RL_REJECT -j DROP

# SSH
ip6tables -N SSH_IN || true
ip6tables -A SSH_IN -m recent --rcheck --seconds 60 --name ssh_knock --mask ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff --rsource -j ACCEPT
ip6tables -A SSH_IN -j RL_REJECT

# Everything that is related or established should be permmited. This is for performance reasons
ip6tables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Accept everything from loopback
ip6tables -A INPUT -i lo+ -j ACCEPT

# SSH
ip6tables -A INPUT -m tcp -p tcp --dport 22 -j SSH_IN

# Call our block-list
ip6tables -A INPUT -j BLOCKED

# Services we provide
ip6tables -A INPUT -m tcp -p tcp --dport 8443 -j ACCEPT
ip6tables -A INPUT -m tcp -p tcp --dport 8080  -j ACCEPT
ip6tables -A INPUT -m tcp -p tcp --dport 465 -j ACCEPT
ip6tables -A INPUT -m tcp -p tcp --dport 25  -j ACCEPT

# Nat port bounces
ip6tables -t nat -A PREROUTING -m tcp -p tcp --dport 80  -j DNAT --to-destination :8080
ip6tables -t nat -A PREROUTING -m tcp -p tcp --dport 443 -j DNAT --to-destination :8443

v6ip="$(dig -tAAAA +short futurology.social)" || true
if [ -n "${v6ip}" ]; then
				ip6tables -t nat -A OUTPUT -m tcp -p tcp --dport 80  -d "${v6ip}/128" -j DNAT --to-destination [::1]:8080
				ip6tables -t nat -A OUTPUT -m tcp -p tcp --dport 443 -d "${v6ip}/128" -j DNAT --to-destination [::1]:8443
				ip6tables -t nat -A OUTPUT -d "${v6ip}/128" -j DNAT --to-destination ::1
fi
