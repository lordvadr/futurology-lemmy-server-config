#!/usr/bin/env bash

. "$(dirname "$(realpath "${0}")")/library.sh" || { >&2 echo "FATAL: Could not instantiate function library."; exit 1; }

path="$(dirname "$(realpath "${0}")")" || die "Could not determine my directory."

[ -d "${path}/../crypto" ] || die "No crypto directory can be found."

pushd "${path}/../crypto" > /dev/null 2>&1 || die "Could not change directory to \"${path}/../crypto\"."

TMPDIR="$(mktemp -d "/tmp/$(basename "${0:65-ssh-keys}").XXXXXXXXXX")" || die "Could not create temporary directory."

aws kms decrypt --ciphertext-blob "$(cat passphrase.kms)" --key-id 50cdd4ff-fa03-48bb-9768-cc3e1ecb9102 --encryption-algorithm RSAES_OAEP_SHA_256 \
	| jq -r .Plaintext | base64 -d > "${TMPDIR}/passphrase" || die "Could not decrypt key passphrase using AKS."

[ -n "${pass}" || 

for k in *_key; do
	cp -f "${k}" "${k}.pub" /etc/ssh
	ssh-keygen -p -P "$(cat "${TMPDIR}/passphrase")" -N "" -f "/etc/ssh/${k}"
done

chmod 600 /etc/ssh/ssh_host_*_key
chmod 644 /etc/ssh/ssh_host_*_key.pub

restorecon -rv /etc/ssh

systemctl restart sshd
