#!/bin/sh
set -euo pipefail

c=./result/bin/concourse
p=./worker
wd="${p}"/work
key="${p}"/pvtkey

mkdir -p "${wd}"
test -f "${key}" || "$(realpath -- "${c}")" generate-key -t ssh -f "${key}"

exec sudo env \
     CONCOURSE_EPHEMERAL=true \
     CONCOURSE_WORK_DIR="$(realpath -- "${wd}")" \
     CONCOURSE_TSA_WORKER_PRIVATE_KEY="$(realpath -- "${key}")" \
     CONCOURSE_LOG_LEVEL="error" \
     "$(realpath -- "${c}")" worker
