#!/usr/bin/env bash

. "$(dirname "$(realpath "${0}")")/library.sh" || { >&2 echo "FATAL: Could not instantiate function library."; exit 1; }

dnf -y update
dnf -y install \
	tmux \
	sendmail \
	unzip \
	podman
