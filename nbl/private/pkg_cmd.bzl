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

"""Command helper and rules for use in projects BUILD files."""

load(
    "@io_bazel_rules_nbl//nbl/private:providers.bzl",
    "PackageInfo",
    "ScriptInfo",
)

def _otrp_keystore_impl(ctx):
    toolchain = ctx.toolchains["@io_bazel_rules_nbl//nbl:toolchain"]
    sdk = toolchain.sdk
    otrp_provision_exe = sdk.otrp.provision_exe
    otrp_keystore = sdk.otrp.keystore
    otrp_suite = sdk.otrp.suite

    ctx.actions.run(
        inputs = [otrp_keystore, ctx.file.srcs, ctx.file.sd_privilege],
        arguments = [
            "-c",
            otrp_keystore.path,
            "-e",
            ctx.file.srcs.path,
            "-o",
            ctx.outputs.out.path,
            "--sd_privilege_file",
            ctx.file.sd_privilege.path,
        ],
        executable = otrp_provision_exe,
        outputs = [ctx.outputs.out],
        tools = otrp_suite,
    )

_otrp_keystore = rule(
    implementation = _otrp_keystore_impl,
    attrs = {
        "srcs": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
        "sd_privilege": attr.label(allow_single_file = True, mandatory = True),
        "out": attr.output(),
    },
    toolchains = ["@io_bazel_rules_nbl//nbl:toolchain"],
)

def _uuid_impl(ctx):
    exec = ctx.file.srcs
    if PackageInfo in ctx.attr.srcs:
        exec = ctx.attr.srcs[PackageInfo].exec
    script = ctx.actions.declare_file(ctx.label.name + ".sh")
    script_content = """
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
""".format(exec = exec.short_path)
    ctx.actions.write(script, script_content, is_executable = True)

    return [DefaultInfo(
        executable = script,
        runfiles = ctx.runfiles(
            files = [exec],
        ),
    )]

_uuid = rule(
    implementation = _uuid_impl,
    attrs = {
        "srcs": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
    },
    outputs = {"out": "%{name}.sh"},
    executable = True,
)

_template_provision = """
#!/bin/bash
set -eo pipefail; [[ "${{TRACE}}" ]] && set -x

{sh_exec} {sh_opts} {sh_host} rm -rf /data/nebula_ta
{sh_exec} {sh_opts} {sh_host} mkdir -p /data/
{cp_exec} {cp_opts} {keystore}/key_store_test {cp_host}/data/nebula_ta
{cp_exec} {cp_opts} {nblruncmd} {cp_host}/data/nblruncmd
{sh_exec} {sh_opts} {sh_host} chmod 755 /data/nblruncmd
echo -n "Provisioning..."
{sh_exec} {sh_opts} {sh_host} nbl_daemon -p /data/nebula_ta
echo "Done"
"""

_template_launch = """
#!/bin/bash
set -eo pipefail; [[ "${{TRACE}}" ]] && set -x

UUID="$({uuid})"
echo -n "Launching..."
{sh_exec} {sh_opts} {sh_host} /data/nblruncmd killall ${{UUID}} || echo
{sh_exec} {sh_opts} {sh_host} nbl_daemon -l ${{UUID}}
echo "Done"
"""

def _register_otrp_cmd_impl(ctx):
    params = ctx.attr.params[ScriptInfo]

    exec = ctx.file.srcs
    if PackageInfo in ctx.attr.srcs:
        exec = ctx.attr.srcs[PackageInfo].exec

    script = ctx.actions.declare_file(ctx.label.name + ".sh")
    script_content = ctx.attr.template.format(
        **params.substitutions
    )
    ctx.actions.write(script, script_content, is_executable = True)
    return [DefaultInfo(
        executable = script,
        runfiles = ctx.runfiles(
            files = [exec] + params.runfiles,
        ),
    )]

_register_otrp_cmd = rule(
    implementation = _register_otrp_cmd_impl,
    attrs = {
        "srcs": attr.label(allow_single_file = True, mandatory = True),
        "params": attr.label(mandatory = True, providers = [ScriptInfo]),
        "template": attr.string(mandatory = True),
    },
    executable = True,
)

def _otrp_params_impl(ctx):
    toolchain = ctx.toolchains["@io_bazel_rules_nbl//nbl:toolchain"]
    sdk = toolchain.sdk
    selected_device = ctx.attr.device[0]

    runfiles = [ctx.file.keystore, ctx.file.uuid, sdk.target.nblruncmd]
    substitutions = {
        "uuid": ctx.file.uuid.short_path,
        "keystore": ctx.file.keystore.short_path,
        "nblruncmd": sdk.target.nblruncmd.short_path,
    }
    if selected_device == "android":
        substitutions.update({
            "sh_exec": "adb",
            "sh_opts": "shell",
            "sh_host": "",
            "cp_exec": "adb",
            "cp_opts": "push",
            "cp_host": "",
        })
    elif selected_device == "qemu":
        substitutions.update({
            "sh_exec": "ssh",
            "sh_opts": "-o StrictHostKeyChecking=no",
            "sh_host": "root@192.168.3.53",
            "cp_exec": "scp",
            "cp_opts": "-r -o StrictHostKeyChecking=no",
            "cp_host": "root@192.168.3.53:",
        })
    else:
        fail("Unsupported device: {} (expected 'qemu' or 'android').".format(ctx.attr.device))

    return [ScriptInfo(substitutions = substitutions, runfiles = runfiles)]

_otrp_params = rule(
    implementation = _otrp_params_impl,
    attrs = {
        "device": attr.string_list(mandatory = True),
        "keystore": attr.label(allow_single_file = True, mandatory = True),
        "uuid": attr.label(allow_single_file = True, mandatory = True),
    },
    provides = [ScriptInfo],
    toolchains = ["@io_bazel_rules_nbl//nbl:toolchain"],
)

def nbl_register_pkgcmds(srcs):
    """Register basic commands for cc_binary or pkg_far.

    Args:
      srcs: the cc_binary, or pkg_far to support basic
        commands: provision, launch ... etc.
    """

    # generate otrp keystore
    _otrp_keystore(
        name = "otrp_keystore",
        out = "keystore",
        sd_privilege = "sd.privilege",
        srcs = srcs,
    )

    # generate uuid.sh
    _uuid(name = "uuid", srcs = srcs)

    # generate providers for different configs
    _otrp_params(
        name = "otrp_params",
        device = select({
            "@io_bazel_rules_nbl//nbl:cfg_android": ["android"],
            "//conditions:default": ["qemu"],
        }),
        keystore = ":otrp_keystore",
        uuid = ":uuid",
    )

    _register_otrp_cmd(
        name = "provision",
        srcs = srcs,
        params = ":otrp_params",
        template = _template_provision,
    )

    _register_otrp_cmd(
        name = "launch",
        srcs = srcs,
        params = ":otrp_params",
        template = _template_launch,
    )
