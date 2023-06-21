#!/usr/bin/env bash

sed -i 's/^\(SELINUX=\).*/\1enforcing/' /etc/selinux/config
touch /.autorelabel
