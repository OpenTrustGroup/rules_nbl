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
load(
    "@io_bazel_rules_nbl//nbl/private:script_templates.bzl",
    "HOST_SCRIPTS",
    "REE_SCRIPTS",
    "TEE_SCRIPTS",
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
        "srcs": attr.label(allow_single_file = True),
        "sd_privilege": attr.label(allow_single_file = True),
        "out": attr.output(),
    },
    toolchains = ["@io_bazel_rules_nbl//nbl:toolchain"],
)

def _uuid_impl(ctx):
    exec = ctx.file.srcs
    if PackageInfo in ctx.attr.srcs:
        exec = ctx.attr.srcs[PackageInfo].exec
    script = ctx.actions.declare_file(ctx.label.name + ".sh")
    script_content = HOST_SCRIPTS["read_uuid"].format(exec = exec.short_path)
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

def _register_otrp_cmd_impl(ctx):
    params = ctx.attr.params[ScriptInfo]

    exec = ctx.file.srcs
    if PackageInfo in ctx.attr.srcs:
        exec = ctx.attr.srcs[PackageInfo].exec

    script = ctx.actions.declare_file(ctx.label.name + ".sh")
    script_content = ctx.attr.template[0].format(
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
        "template": attr.string_list(mandatory = True),
    },
    executable = True,
)

def _otrp_params_impl(ctx):
    toolchain = ctx.toolchains["@io_bazel_rules_nbl//nbl:toolchain"]
    sdk = toolchain.sdk
    selected_device = ctx.attr.device[0]

    # TODO: Remove nblruncmd deps in non-nebula build
    runfiles = [ctx.file.srcs, sdk.target.nblruncmd]
    runfiles += ctx.files.uuid if ctx.files.uuid else []
    runfiles += ctx.files.keystore if ctx.files.keystore else []
    substitutions = {
        "exec_path": ctx.file.srcs.short_path,
        "exec_name": ctx.file.srcs.basename,
        "uuid": ctx.files.uuid[0].short_path if ctx.files.uuid else "",
        "keystore": ctx.files.keystore[0].short_path if ctx.files.keystore else "",
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
        "device": attr.string_list(),
        "keystore": attr.label_list(allow_files = True),
        "uuid": attr.label_list(allow_files = True),
        "srcs": attr.label(allow_single_file = True, mandatory = True),
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
        name = "_otrp_params",
        device = select({
            "@io_bazel_rules_nbl//nbl:cfg_android": ["android"],
            "//conditions:default": ["qemu"],
        }),
        keystore = select({
            "@io_bazel_rules_nbl//platforms:fuchsia": [":otrp_keystore"],
            "@io_bazel_rules_nbl//platforms:linux": [],
        }),
        uuid = select({
            "@io_bazel_rules_nbl//platforms:fuchsia": [":uuid"],
            "@io_bazel_rules_nbl//platforms:linux": [],
        }),
        srcs = srcs,
    )

    _register_otrp_cmd(
        name = "provision",
        srcs = srcs,
        params = ":_otrp_params",
        template = select({
            "@io_bazel_rules_nbl//platforms:fuchsia": [TEE_SCRIPTS["provision"]],
            "@io_bazel_rules_nbl//platforms:linux": [REE_SCRIPTS["provision"]],
        }),
    )

    _register_otrp_cmd(
        name = "launch",
        srcs = srcs,
        params = ":_otrp_params",
        template = select({
            "@io_bazel_rules_nbl//platforms:fuchsia": [TEE_SCRIPTS["launch"]],
            "@io_bazel_rules_nbl//platforms:linux": [REE_SCRIPTS["launch"]],
        }),
    )
