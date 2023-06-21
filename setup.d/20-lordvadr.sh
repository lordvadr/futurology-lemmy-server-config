#!/usr/bin/env bash

id lordvadr && exit 0

useradd -m -u 1000 -U -G wheel lordvadr

mkdir ~lordvadr/.ssh

cat << EOF > ~lordvadr/.ssh/authorized_keys
sk-ecdsa-sha2-nistp256@openssh.com AAAAInNrLWVjZHNhLXNoYTItbmlzdHAyNTZAb3BlbnNzaC5jb20AAAAIbmlzdHAyNTYAAABBBIEez5yzyr3RTJQlVzstYEmGCuzkRPwfRAW04CHr6HzHhsVCsAEC3UiL1c2kD5fMEUQdHeg5ViIm7KV8yhvK7uYAAAAEc3NoOg== lordvadr
EOF

chown -R lordvadr:lordvadr ~lordvadr
chmod 700 ~lordvadr/.ssh
chmod 644 ~lordvadr/.ssh/authorized_keys
