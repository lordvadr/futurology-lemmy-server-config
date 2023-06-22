#!/usr/bin/env bash

set -euo pipefail

log() {
	>&2 echo "${@:-UNKNOWN MESSAGE}"
}

die() {
	log "FATAL: ${@:-UNKNOWN FATAL MESSAGE}"
	exit 1
}

cleanup() {
	[ -z "${TMPDIR:=}" ] || [ ! -d "${TMPDIR}" ] || rm -rf "${TMPDIR}"
	unset TMPDIR
}

last_signed_commit() {
	local dir=0
	[ -z "${2:-}" ] || [ ! -d "${2}" ] || { dir=1; pushd "${2}" > /dev/null 2>&1 || die "Could not change directory to \"${2}\"."; } 

	[ -z "${1:-}" ] || git checkout "${1}" || die "Could not checkout branch \"${1}\"."

	COMMIT=""

	for c in $(git log --pretty=format:"%H"); do
		if git verify-commit "${c}"; then
			COMMIT="${c}"
			break
		else
			COMMIT=""
		fi
	done

	[ "${dir}" != "1" ] || popd > /dev/null 2>&1

	[ -n "${COMMIT}" ] && echo "${COMMIT}"
}

[ -z "${DEBUG+x}" ] || { log "DEBUG environment variable is set. Enabling debugging output."; set -x; }

trap cleanup EXIT
