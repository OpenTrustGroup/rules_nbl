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
load("@sdk_info//:sdk_path.bzl", "sdk_path")
load("@sdk_info//:otrp_keystore_path.bzl", "otrp_keystore_path")

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
            otrp_keystore_path if otrp_keystore_path else otrp_keystore.path,
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
    script_content = HOST_SCRIPTS["read_uuid"].format(
        exec = exec.short_path,
        sdk_path = sdk_path,
    )
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

_register_otrp_cmd_test = rule(
    implementation = _register_otrp_cmd_impl,
    attrs = {
        "srcs": attr.label(allow_single_file = True, mandatory = True),
        "params": attr.label(mandatory = True, providers = [ScriptInfo]),
        "template": attr.string_list(mandatory = True),
    },
    test = True,
)

def _otrp_params_impl(ctx):
    toolchain = ctx.toolchains["@io_bazel_rules_nbl//nbl:toolchain"]
    sdk = toolchain.sdk

    final_keystore_path = ""
    if ctx.files.keystore:
        tmp_path = otrp_keystore_path if otrp_keystore_path else sdk.otrp.keystore.path
        provision_folder = tmp_path.split("/").pop()
        final_keystore_path = "/".join([ctx.files.keystore[0].short_path, provision_folder])

    # TODO: Remove nblruncmd deps in non-nebula build
    runfiles = [ctx.file.srcs, sdk.target.nblruncmd]
    runfiles += [sdk.target.taloaderproxyd]
    runfiles += ctx.files.uuid if ctx.files.uuid else []
    runfiles += ctx.files.keystore if ctx.files.keystore else []
    substitutions = {
        "exec_path": ctx.file.srcs.short_path,
        "exec_name": ctx.file.srcs.basename,
        "uuid": ctx.files.uuid[0].short_path if ctx.files.uuid else "",
        "keystore": final_keystore_path,
        "nblruncmd": sdk.target.nblruncmd.short_path,
        "taloaderproxyd": sdk.target.taloaderproxyd.short_path,
    }

    return [ScriptInfo(substitutions = substitutions, runfiles = runfiles)]

_otrp_params = rule(
    implementation = _otrp_params_impl,
    attrs = {
        "keystore": attr.label_list(allow_files = True),
        "uuid": attr.label_list(allow_files = True),
        "srcs": attr.label(allow_single_file = True, mandatory = True),
    },
    provides = [ScriptInfo],
    toolchains = ["@io_bazel_rules_nbl//nbl:toolchain"],
)

def nbl_register_pkgcmds(srcs, name = "default"):
    """Register basic commands for cc_binary or pkg_far.

    Args:
      srcs: the cc_binary, or pkg_far to support basic
        commands: provision, launch ... etc.
      name: modify the naming of basic comamnds. It will
        become provision-xxx, launch-xxx, xxx is the name
        you given. This is used to support registering
        multiple pkgcmds
    """

    # generate otrp keystore
    _otrp_keystore(
        name = "otrp_keystore-%s" % name,
        out = "keystore-%s" % name,
        sd_privilege = "sd.privilege",
        srcs = srcs,
    )

    # generate uuid.sh
    _uuid(name = "uuid-%s" % name, srcs = srcs)

    # generate providers for different configs
    _otrp_params(
        name = "_otrp_params-%s" % name,
        keystore = select({
            "@io_bazel_rules_nbl//platforms:fuchsia": [":otrp_keystore-%s" % name],
            "@io_bazel_rules_nbl//platforms:linux": [],
        }),
        uuid = select({
            "@io_bazel_rules_nbl//platforms:fuchsia": [":uuid-%s" % name],
            "@io_bazel_rules_nbl//platforms:linux": [],
        }),
        srcs = srcs,
    )

    _register_otrp_cmd(
        name = "provision" if name == "default" else ("provision-%s" % name),
        srcs = srcs,
        params = ":_otrp_params-%s" % name,
        template = select({
            "@io_bazel_rules_nbl//platforms:fuchsia": [TEE_SCRIPTS["provision"]],
            "@io_bazel_rules_nbl//platforms:linux": [REE_SCRIPTS["provision"]],
        }),
    )

    _register_otrp_cmd_test(
        name = "provision-test" if name == "default" else ("provision-test-%s" % name),
        srcs = srcs,
        params = ":_otrp_params-%s" % name,
        template = select({
            "@io_bazel_rules_nbl//platforms:fuchsia": [TEE_SCRIPTS["provision"]],
            "@io_bazel_rules_nbl//platforms:linux": [REE_SCRIPTS["provision"]],
        }),
        tags = ["external"],
    )

    _register_otrp_cmd(
        name = "launch" if name == "default" else ("launch-%s" % name),
        srcs = srcs,
        params = ":_otrp_params-%s" % name,
        template = select({
            "@io_bazel_rules_nbl//platforms:fuchsia": [TEE_SCRIPTS["launch"]],
            "@io_bazel_rules_nbl//platforms:linux": [REE_SCRIPTS["launch"]],
        }),
    )

    _register_otrp_cmd_test(
        name = "launch-test" if name == "default" else ("launch-test-%s" % name),
        srcs = srcs,
        params = ":_otrp_params-%s" % name,
        template = select({
            "@io_bazel_rules_nbl//platforms:fuchsia": [TEE_SCRIPTS["launch_test"]],
            "@io_bazel_rules_nbl//platforms:linux": [REE_SCRIPTS["launch"]],
        }),
        tags = ["external"],
    )

    _register_otrp_cmd(
        name = "trace" if name == "default" else ("trace-%s" % name),
        srcs = srcs,
        params = ":_otrp_params-%s" % name,
        template = select({
            "@io_bazel_rules_nbl//platforms:fuchsia": [TEE_SCRIPTS["trace"]],
            "@io_bazel_rules_nbl//platforms:linux": [],
        }),
    )

    _register_otrp_cmd(
        name = "attach" if name == "default" else ("attach-%s" % name),
        srcs = srcs,
        params = ":_otrp_params-%s" % name,
        template = select({
            "@io_bazel_rules_nbl//platforms:fuchsia": [TEE_SCRIPTS["attach"]],
            "@io_bazel_rules_nbl//platforms:linux": [],
        }),
    )

    _register_otrp_cmd(
        name = "export" if name == "default" else ("export-%s" % name),
        srcs = srcs,
        params = ":_otrp_params-%s" % name,
        template = select({
            "@io_bazel_rules_nbl//platforms:fuchsia": [TEE_SCRIPTS["export"]],
            "@io_bazel_rules_nbl//platforms:linux": [],
        }),
    )
