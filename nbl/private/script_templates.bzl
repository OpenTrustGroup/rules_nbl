# Copyright 2020 The GoldenRiver Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Script templates"""

_parse_target_device = """
# use TARGET_DEVICE env var if provided, else use the value provided by bazel
readonly target_device="${{TARGET_DEVICE:-{device}}}"

declare sh_exec=""
declare sh_opts=""
declare sh_host=""
declare cp_exec=""
declare cp_opts=""
declare cp_host=""

IFS=':'
read -a device_params <<< "$target_device"

unset IFS

if [[ "${{device_params[0]}}" == "ssh" ]]; then
  sh_exec="ssh"
  sh_opts="-o StrictHostKeyChecking=no -o ConnectTimeout=5 -p ${{device_params[3]}}"
  sh_host="${{device_params[1]}}@${{device_params[2]}}"
  cp_exec="scp"
  cp_opts="-r -o StrictHostKeyChecking=no -o ConnectTimeout=5 -P ${{device_params[3]}}"
  cp_host="${{device_params[1]}}@${{device_params[2]}}:"
elif [[ "${{device_params[0]}}" == "adb" ]]; then
  sh_exec="adb"
  sh_opts="-s ${{device_params[1]}} -H ${{device_params[2]}} -P ${{device_params[3]}} shell"
  sh_host=""
  cp_exec="adb"
  cp_opts="-s ${{device_params[1]}} -H ${{device_params[2]}} -P ${{device_params[3]}} push"
  cp_host=""
else
  echo "Unsupported target device: $target_device"
  exit 1
fi
"""

_tee_provision_tpl = """
#!/bin/bash
set -eo pipefail; [[ "${{TRACE}}" ]] && set -x

%s

echo "Provisioning..."
eval ${{sh_exec}} ${{sh_opts}} ${{sh_host}} rm -rf /data/nebula_ta
eval ${{sh_exec}} ${{sh_opts}} ${{sh_host}} mkdir -p /data/
eval ${{cp_exec}} ${{cp_opts}} {keystore}/key_store_test ${{cp_host}}/data/nebula_ta
eval ${{cp_exec}} ${{cp_opts}} {nblruncmd} ${{cp_host}}/data/nblruncmd
eval ${{sh_exec}} ${{sh_opts}} ${{sh_host}} chmod 755 /data/nblruncmd
eval ${{sh_exec}} ${{sh_opts}} ${{sh_host}} nbl_daemon -p /data/nebula_ta
echo "Done"
""" % (_parse_target_device)

_tee_launch_tpl = """
#!/bin/bash
set -eo pipefail; [[ "${{TRACE}}" ]] && set -x

%s

if [[ "${{@}}" != "" ]]; then
    ARGS="-a \'${{@}}\'"
fi

UUID="$({uuid})"
echo "Launching..."
eval ${{sh_exec}} ${{sh_opts}} ${{sh_host}} /data/nblruncmd killall ${{UUID%%-*}}* || echo
eval ${{sh_exec}} ${{sh_opts}} ${{sh_host}} nbl_daemon -l ${{UUID}} ${{ARGS}}
echo "Done"
""" % (_parse_target_device)

_tee_trace_tpl = """
#!/bin/bash
set -eo pipefail; [[ "${{TRACE}}" ]] && set -x

%s

trap func "SIGINT"
func() {{
    PID=$(eval ${{sh_exec}} ${{sh_opts}} ${{sh_host}} ps -Ao pid,comm | grep nblruncmd | awk {{'print $1'}} | head -n 1)
    eval ${{sh_exec}} ${{sh_opts}} ${{sh_host}} kill -SIGINT ${{PID}}
}}

if [[ "${{@}}" != "" ]]; then
    ARGS="-a \'${{@}}\'"
fi

UUID="$({uuid})"
eval ${{sh_exec}} ${{sh_opts}} ${{sh_host}} /data/nblruncmd killall ${{UUID%%-*}}* || echo

eval ${{sh_exec}} ${{sh_opts}} ${{sh_host}} /data/nblruncmd trace record  --uuid=${{UUID}} ${{ARGS}} &
PID=$!
wait ${{PID}} || echo
eval ${{sh_exec}} ${{sh_opts}} ${{sh_host}} /data/nblruncmd cat /data/trace.json > trace.json
""" % (_parse_target_device)

_tee_attach_tpl = """
#!/bin/bash
set -eo pipefail; [[ "${{TRACE}}" ]] && set -x

%s

trap func "SIGINT"
func() {{
    PID=$(eval ${{sh_exec}} ${{sh_opts}} ${{sh_host}} ps -Ao pid,comm | grep nblruncmd | awk {{'print $1'}} | head -n 1)
    eval ${{sh_exec}} ${{sh_opts}} ${{sh_host}} kill -SIGINT ${{PID}}
}}

UUID="$({uuid})"
PID=$(eval ${{sh_exec}} ${{sh_opts}} ${{sh_host}} /data/nblruncmd ps | grep ${{UUID%%-*}} | grep -oE "p:([0-9]+)" | sed s/p:// || echo)
if [[ "${{PID}}" == "" ]]; then
    echo "You should launch the process first"
    exit 0
fi

eval ${{sh_exec}} ${{sh_opts}} ${{sh_host}} /data/nblruncmd trace record  --attach=${{PID}} &
PID=$!
wait ${{PID}} || echo
eval ${{sh_exec}} ${{sh_opts}} ${{sh_host}} /data/nblruncmd cat /data/trace.json > trace.json
""" % (_parse_target_device)

_ree_provision_tpl = """
#!/bin/bash
set -eo pipefail; [[ "${{TRACE}}" ]] && set -x

%s

echo "Provisioning..."
eval ${{sh_exec}} ${{sh_opts}} ${{sh_host}} mkdir -p /data/
eval ${{cp_exec}} ${{cp_opts}} ${{exec_path}} ${{cp_host}}/data/{exec_name}
eval ${{sh_exec}} ${{sh_opts}} ${{sh_host}} chmod 755 /data/{exec_name}
echo "Done"
""" % (_parse_target_device)

_ree_launch_tpl = """
#!/bin/bash
set -eo pipefail; [[ "${{TRACE}}" ]] && set -x

%s

echo "Launching..."
eval ${{sh_exec}} ${{sh_opts}} ${{sh_host}} /data/{exec_name}
echo "Done"
""" % (_parse_target_device)

_host_read_uuid_tpl = """
#!/bin/bash
set -eo pipefail; [[ "${{TRACE}}" ]] && set -x

grok_offset() {{
  local line
  while read line; do
    case "$line" in
    # Section Headers for .note.nebula.app.manifest
    #   [ 2] .note.nebula.app.manifest NOTE            00000000000002b8 0002b8 0000a8 00   A  0   0  4
    *.note.nebula.app.manifest*NOTE*)
      local words=($line)
      local off=$(printf '%#u' 0x${{words[4]}})
      echo $off
      return 0
      ;;
    esac
  done
  return 1
}}

# See |nbl_app_manifest.h| for details
off=$(($(readelf -W -S {exec} | grok_offset) + 0x18))

# Read 16 bytes (32 chars) into a string
v=$(hexdump -s ${{off}} -n 16 -e '/1 "%02x"' {exec})

# Fill each field from array values and arrange by endian
time_low=$(printf %s "${{v:6:2}}${{v:4:2}}${{v:2:2}}${{v:0:2}}")
time_mid=$(printf %s "${{v:10:2}}${{v:8:2}}")
time_high_version=$(printf %s "${{v:14:2}}${{v:12:2}}")
clock_seq=$(printf %s "${{v:16:4}}")
node=$(printf %s "${{v:20}}")
echo "${{time_low}}-${{time_mid}}-${{time_high_version}}-${{clock_seq}}-${{node}}"
"""

REE_SCRIPTS = {
    "provision": _ree_provision_tpl,
    "launch": _ree_launch_tpl,
}

TEE_SCRIPTS = {
    "provision": _tee_provision_tpl,
    "launch": _tee_launch_tpl,
    "trace": _tee_trace_tpl,
    "attach": _tee_attach_tpl,
}

HOST_SCRIPTS = {
    "read_uuid": _host_read_uuid_tpl,
}
