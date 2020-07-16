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

_tee_provision_tpl = """
#!/bin/bash
set -eo pipefail; [[ "${{TRACE}}" ]] && set -x

echo "Provisioning..."
{sh_exec} {sh_opts} {sh_host} rm -rf /data/nebula_ta
{sh_exec} {sh_opts} {sh_host} mkdir -p /data/
{cp_exec} {cp_opts} {keystore}/key_store_test {cp_host}/data/nebula_ta
{cp_exec} {cp_opts} {nblruncmd} {cp_host}/data/nblruncmd
{sh_exec} {sh_opts} {sh_host} chmod 755 /data/nblruncmd
{sh_exec} {sh_opts} {sh_host} nbl_daemon -p /data/nebula_ta
echo "Done"
"""

_tee_launch_tpl = """
#!/bin/bash
set -eo pipefail; [[ "${{TRACE}}" ]] && set -x

if [[ "${{@}}" != "" ]]; then
    ARGS="-a \'${{@}}\'"
fi

UUID="$({uuid})"
echo "Launching..."
{sh_exec} {sh_opts} {sh_host} /data/nblruncmd killall ${{UUID%-*}}* || echo
{sh_exec} {sh_opts} {sh_host} nbl_daemon -l ${{UUID}} ${{ARGS}}
echo "Done"
"""

_tee_trace_tpl = """
#!/bin/bash
trap func "SIGINT"
func() {{
    PID=`{sh_exec} {sh_opts} {sh_host} ps -Ao pid,comm | grep nblruncmd | awk {{'print \$1'}} | head -n 1`
    {sh_exec} {sh_opts} {sh_host} kill -SIGINT ${{PID}}
}}
set -eo pipefail; [[ "${{TRACE}}" ]] && set -x

if [[ "${{@}}" != "" ]]; then
    ARGS="-a \'${{@}}\'"
fi

UUID="$({uuid})"
{sh_exec} {sh_opts} {sh_host} /data/nblruncmd killall ${{UUID%-*}}* || echo

{sh_exec} {sh_opts} {sh_host} /data/nblruncmd trace record  --uuid=${{UUID}} ${{ARGS}} &
PID=$!
wait ${{PID}} || echo
{sh_exec} {sh_opts} {sh_host} /data/nblruncmd cat /data/trace.json > trace.json
"""

_tee_attach_tpl = """
#!/bin/bash
trap func "SIGINT"
func() {{
    PID=`{sh_exec} {sh_opts} {sh_host} ps -Ao pid,comm | grep nblruncmd | awk {{'print \$1'}} | head -n 1`
    {sh_exec} {sh_opts} {sh_host} kill -SIGINT ${{PID}}
}}
set -eo pipefail; [[ "${{TRACE}}" ]] && set -x

UUID="$({uuid})"
PID=`{sh_exec} {sh_opts} {sh_host} /data/nblruncmd ps | grep ${{UUID%-*}} | grep -oE "p:([0-9]+)" | sed s/p:// || echo`
if [[ "${{PID}}" == "" ]]; then
    echo "You should launch the process first"
    exit 0
fi

{sh_exec} {sh_opts} {sh_host} /data/nblruncmd trace record  --attach=${{PID}} &
PID=$!
wait ${{PID}} || echo
{sh_exec} {sh_opts} {sh_host} /data/nblruncmd cat /data/trace.json > trace.json
"""

_ree_provision_tpl = """
#!/bin/bash
set -eo pipefail; [[ "${{TRACE}}" ]] && set -x

echo "Provisioning..."
{sh_exec} {sh_opts} {sh_host} mkdir -p /data/
{cp_exec} {cp_opts} {exec_path} {cp_host}/data/{exec_name}
{sh_exec} {sh_opts} {sh_host} chmod 755 /data/{exec_name}
echo "Done"
"""

_ree_launch_tpl = """
#!/bin/bash
set -eo pipefail; [[ "${{TRACE}}" ]] && set -x

echo "Launching..."
{sh_exec} {sh_opts} {sh_host} /data/{exec_name}
echo "Done"
"""

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
