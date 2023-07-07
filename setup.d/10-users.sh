#!/usr/bin/env bash

set -euo pipefail

. "$(dirname "$(realpath "${0}")")/library.sh" || { >&2 echo "FATAL: Could not instantiate function library."; exit 1; }

TMPDIR="$(mktemp -d /tmp/$(basename "${0}").XXXXXXXX)" || die "Could not create temporary directory."

git clone "https://github.com/lordvadr/futurology-ssh-keys.git" "${TMPDIR}" || die "Could not clone ssh users repository."

pushd "${TMPDIR}" || die "Could not change working directory to \"${TMPDIR}\"."

commit="$(last_signed_commit)"

[ -n "${commit}" ] || die "No signed commit found."

git checkout "${commit}" || die "Could not checkout commit \"${commit}\"."

./install.sh

useradd lemmyrun
loginctl enable-linger lemmyrun
