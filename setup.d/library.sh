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

[ -z "${DEBUG+x}" ] || { log "DEBUG environment variable is set. Enabling debugging output."; set -x; }

trap cleanup EXIT
