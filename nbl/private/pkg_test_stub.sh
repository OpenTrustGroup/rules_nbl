#!/bin/bash
set -euo pipefail; [[ "${TRACE:-}" ]] && set -x

echo "Provisioning required packages..."
%prerequisites%

echo "Parsing target device..."
%target_device_parsing_stub%


all_tests=(
%tests%
)

for test in ${all_tests[@]}; do
  echo "Running: \"${test}\" ${@}"
  eval ${sh_exec} ${sh_opts} ${sh_host} /data/nblruncmd ${test} ${@}
done