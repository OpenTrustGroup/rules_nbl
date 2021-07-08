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
readonly target_device="${{GX_DEVICE}}"

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
  sh_opts="-F /dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=5 -p ${{device_params[3]}}"
  sh_host="${{device_params[1]}}@${{device_params[2]}}"
  cp_exec="scp"
  cp_opts="-F /dev/null -r -o StrictHostKeyChecking=no -o ConnectTimeout=5 -P ${{device_params[3]}}"
  cp_host="${{device_params[1]}}@${{device_params[2]}}:"
elif [[ "${{device_params[0]}}" == "adb" ]]; then
  sh_exec="adb"
  sh_opts="${{device_params[1]:+-s}} ${{device_params[1]}} -H ${{device_params[2]}} -P ${{device_params[3]}} shell"
  sh_host=""
  cp_exec="adb"
  cp_opts="${{device_params[1]:+-s}} ${{device_params[1]}} -H ${{device_params[2]}} -P ${{device_params[3]}} push"
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
eval ${{cp_exec}} ${{cp_opts}} {keystore} ${{cp_host}}/data/nebula_ta
eval ${{sh_exec}} ${{sh_opts}} ${{sh_host}} nbl_daemon -p /data/nebula_ta
eval ${{sh_exec}} ${{sh_opts}} ${{sh_host}} /data/nblruncmd dm scan || echo
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

_tee_launch_test_tpl = """
#!/bin/bash
set -eo pipefail; [[ "${{TRACE}}" ]] && set -x

%s

if [[ "${{@}}" != "" ]]; then
    ARGS="-a \'${{@}}\'"
fi

UUID="$({uuid})"
echo "Launching and wait for result..."
eval ${{sh_exec}} ${{sh_opts}} ${{sh_host}} /data/nblruncmd killall ${{UUID%%-*}}* || echo
eval ${{sh_exec}} ${{sh_opts}} ${{sh_host}} nbl_daemon -w ${{UUID}} ${{ARGS}}
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

_tee_export_tpl = """
#!/bin/bash
set -eo pipefail; [[ "${{TRACE}}" ]] && set -x

readonly unsigned_ta_path="{exec_path}"
readonly signed_ta_path="{keystore}"

function show-help() {{
  echo ""
  echo "Available options:"
  echo "  -s                export signed TA image (default: export unsigned TA image)"
  echo "  -o  <out-dir>     output directory"
  echo ""
}}

echo "Exporting TA image..."

declare export_unsigned_ta="true"
declare output_dir=""

while [[ $# -ne 0 ]]; do
  case "$1" in
    -s)
      export_unsigned_ta="false"
      ;;
    -o)
      if [[ $# -lt 2 ]]; then
        show-help
        exit 1
      fi
      output_dir="$(realpath $2)"
      shift
      ;;
    -h)
      show-help
      exit 0
  esac
  shift
done

if [[ ! -e "$output_dir" ]]; then
  echo "Error: output directory not found: $output_dir"
  exit 1
fi

if [[ "$export_unsigned_ta" == "true" ]]; then
  rm -f "$output_dir/$(basename "$unsigned_ta_path")"
  cp -L "$unsigned_ta_path" "$output_dir/"
else
  cp -r "$signed_ta_path" "$output_dir/"
fi

echo "Done"
"""

_ree_provision_tpl = """
#!/bin/bash
set -eo pipefail; [[ "${{TRACE}}" ]] && set -x

%s

echo "Provisioning..."
eval ${{sh_exec}} ${{sh_opts}} ${{sh_host}} mkdir -p /data/
eval ${{cp_exec}} ${{cp_opts}} {exec_path} ${{cp_host}}/data/{exec_name}
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

ta_file="{exec}"
tmp_out_file="$(basename {exec}).json"
uuid_regex='"uuid":"([0-9a-f\\-]+)"'
elf_tool_path="{sdk_path}/run/otrp/elf_tool"

echo "" > ${{tmp_out_file}}
java -jar ${{elf_tool_path}}/nebula_elf_tool.jar get_manifest \
      --in_file "${{ta_file}}" \
      --out_file ${{tmp_out_file}} \
      --far_tool_file ${{elf_tool_path}}/far > /dev/null

if [[ "$(cat ${{tmp_out_file}})" =~ $uuid_regex ]]; then
  echo ${{BASH_REMATCH[1]}}
else
  >&2 echo "Cannot find UUID in: \"${{ta_file}}\""
  exit 1
fi

"""

REE_SCRIPTS = {
    "provision": _ree_provision_tpl,
    "launch": _ree_launch_tpl,
}

TEE_SCRIPTS = {
    "provision": _tee_provision_tpl,
    "launch": _tee_launch_tpl,
    "launch_test": _tee_launch_test_tpl,
    "trace": _tee_trace_tpl,
    "attach": _tee_attach_tpl,
    "export": _tee_export_tpl,
}

HOST_SCRIPTS = {
    "read_uuid": _host_read_uuid_tpl,
}
