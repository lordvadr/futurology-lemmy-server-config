#!/usr/bin/env bash

. "$(dirname "$(realpath "${0}")")/setup.d/library.sh" || { >&2 echo "FATAL: Could not instantiate function library."; exit 1; }

cleanup() {
	local rv="${?}"
	if [ "${rv}" == "0" ]; then
		echo "Script has finished successfully."
	else
		echo "Script failed to complete successfully."
	fi
}

trap cleanup EXIT

for f in setup.d/*.sh; do
	echo "========== examining ${f} =========="
	bash -n "${f}" || { echo "${f} fails linting, skipping."; continue; }
  ret=0
  [ -x "${f}" ] || { echo "${f} is not executable. Skipping."; continue; }
  "${f}" || ret="${?}"
	echo "=============== ${f} Exited with return code ${ret} ======="
done
