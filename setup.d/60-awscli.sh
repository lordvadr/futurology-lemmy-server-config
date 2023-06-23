#!/usr/bin/env bash

. "$(dirname "$(realpath "${0}")")/library.sh" || { >&2 echo "FATAL: Could not instantiate function library."; exit 1; }

TMPDIR="$(mktemp -d "/tmp/$(basename "${0:-awscli}").XXXXXXXXXX")" || die "Could not create temporary directory."

pushd "${TMPDIR}" > /dev/null 2>&1 || die "Could not change directory to temporary directory \"${TMPDIR}\"."

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" || die "Could not download awscli"

unzip "awscliv2.zip" || die "Could not unzip awscli."

aws/install || aws/install --update || die "Could not install or update awscli."
