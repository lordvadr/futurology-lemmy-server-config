#!/usr/bin/env bash

. "$(dirname "$(realpath "${0}")")/library.sh" || { >&2 echo "FATAL: Could not instantiate function library."; exit 1; }

sed -i 's/^\(SELINUX=\).*/\1enforcing/' /etc/selinux/config
touch /.autorelabel
