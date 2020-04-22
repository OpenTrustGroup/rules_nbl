load(
    "@io_bazel_rules_nbl//nbl/private:providers.bzl",
    "PackageInfo",
)

def _make_provision_impl(ctx):
    ctx.actions.run(
        inputs = [ctx.file.keystore, ctx.file.srcs, ctx.file.sd_privilege],
        arguments = [
            "-c",
            ctx.file.keystore.path,
            "-e",
            ctx.file.srcs.path,
            "-o",
            ctx.outputs.out.path,
            "--sd_privilege_file",
            ctx.file.sd_privilege.path,
        ],
        executable = ctx.executable.provision,
        outputs = [ctx.outputs.out],
        tools = ctx.files.otrp_runfiles,
    )

_make_provision = rule(
    implementation = _make_provision_impl,
    attrs = {
        "srcs": attr.label(
            allow_single_file = True,
            mandatory = True,
            providers = [PackageInfo],
        ),
        "provision": attr.label(
            default = Label("@nbl_sdk//:otrp_provision"),
            cfg = "host",
            executable = True,
            allow_single_file = True,
        ),
        "keystore": attr.label(
            default = Label("@nbl_sdk//:otrp_keystore"),
            allow_single_file = True,
        ),
        "sd_privilege": attr.label(allow_single_file = True, mandatory = True),
        "otrp_runfiles": attr.label_list(
            allow_files = True,
            default = [
                Label("@nbl_sdk//:otrp_provision_tool"),
                Label("@nbl_sdk//:otrp_sign_tool"),
                Label("@nbl_sdk//:otrp_elf_tool"),
            ],
        ),
        "out": attr.output(),
    },
)

def _register_cmd_launch_impl(ctx):
    exec = ctx.file.srcs
    if PackageInfo in ctx.attr.srcs:
        exec = ctx.attr.srcs[PackageInfo].exec
    script = ctx.actions.declare_file(ctx.label.name + ".sh")
    script_content = """
#!/bin/bash
[[ "${{TRACE}}" ]] && set -x

[[ $(readelf -n {exec}) =~ offset\\ (0x[0-9a-f]+) ]] || exit 1
read -r -d '' -a v < <(hexdump -s $((${{BASH_REMATCH[1]}} + 0x18)) -n 16 -e '/1 "%02x"' {exec})

time_low=$(printf %s "${{v:6:2}}${{v:4:2}}${{v:2:2}}${{v:0:2}}")
time_mid=$(printf %s "${{v:10:2}}${{v:8:2}}")
time_high_version=$(printf %s "${{v:14:2}}${{v:12:2}}")
clock_seq=$(printf %s "${{v:16:4}}")
node=$(printf %s "${{v:20}}")

UUID="${{time_low}}-${{time_mid}}-${{time_high_version}}-${{clock_seq}}-${{node}}"
echo -n "Launching..."
PID=`{sh_exec} {sh_opts} {sh_host} /data/nblruncmd ps | grep ${{UUID}} | awk '{{split($1,result,":"); printf result[2]}}'`
[[ ! -z "${{PID}}" ]] && {sh_exec} {sh_opts} {sh_host} /data/nblruncmd kill ${{PID}}
{sh_exec} {sh_opts} {sh_host} nbl_daemon -l ${{UUID}}
echo "Done"

    """.format(
        exec = exec.short_path,
        sh_exec = ctx.attr.sh_exec,
        sh_opts = ctx.attr.sh_opts,
        sh_host = ctx.attr.sh_host,
    )
    ctx.actions.write(script, script_content, is_executable = True)
    return [DefaultInfo(
        executable = script,
        runfiles = ctx.runfiles(
            files = [ctx.file.srcs, exec],
        ),
    )]

_register_cmd_launch = rule(
    implementation = _register_cmd_launch_impl,
    attrs = {
        "srcs": attr.label(allow_single_file = True, mandatory = True),
        "sh_exec": attr.string(mandatory = True),
        "sh_opts": attr.string(default = ""),
        "sh_host": attr.string(default = ""),
    },
    executable = True,
)

def _register_cmd_provision_impl(ctx):
    script = ctx.actions.declare_file(ctx.label.name + ".sh")
    script_content = """
#!/bin/bash
set -eo pipefail; [[ "${{TRACE}}" ]] && set -x

{sh_exec} {sh_opts} {sh_host} rm -rf /data/nebula_ta
{sh_exec} {sh_opts} {sh_host} mkdir -p /data/
{cp_exec} {cp_opts} {otrp_pkg}/key_store_test {cp_host}/data/nebula_ta
echo -n "Provisioning..."
{sh_exec} {sh_opts} {sh_host} nbl_daemon -p /data/nebula_ta
echo "Done"
    """.format(
        sh_exec = ctx.attr.sh_exec,
        sh_opts = ctx.attr.sh_opts,
        sh_host = ctx.attr.sh_host,
        cp_exec = ctx.attr.cp_exec,
        cp_opts = ctx.attr.cp_opts,
        cp_host = ctx.attr.cp_host,
        otrp_pkg = ctx.file.otrp_pkg.short_path,
    )
    ctx.actions.write(script, script_content, is_executable = True)
    return [DefaultInfo(
        executable = script,
        runfiles = ctx.runfiles(
            files = [ctx.file.srcs, ctx.file.otrp_pkg],
        ),
    )]

_register_cmd_provision = rule(
    implementation = _register_cmd_provision_impl,
    attrs = {
        "srcs": attr.label(allow_single_file = True, mandatory = True),
        "sh_exec": attr.string(mandatory = True),
        "sh_opts": attr.string(default = ""),
        "sh_host": attr.string(default = ""),
        "cp_exec": attr.string(mandatory = True),
        "cp_opts": attr.string(default = ""),
        "cp_host": attr.string(default = ""),
        "otrp_pkg": attr.label(allow_single_file = True, mandatory = True),
    },
    executable = True,
)

def register_cmd_provision(**kwargs):
    _register_cmd_provision(
        name = "provision_qemu",
        sh_exec = "ssh",
        sh_opts = "-o StrictHostKeyChecking=no",
        sh_host = "root@192.168.3.53",
        cp_exec = "scp",
        cp_opts = "-r -o StrictHostKeyChecking=no",
        cp_host = "root@192.168.3.53:",
        otrp_pkg = ":make_provision",
        **kwargs
    )
    _register_cmd_provision(
        name = "provision_android",
        sh_exec = "adb",
        sh_opts = "",
        sh_host = "shell",
        cp_exec = "adb",
        cp_opts = "",
        cp_host = "push",
        otrp_pkg = ":make_provision",
        **kwargs
    )

def nbl_register_pkgcmds(**kwargs):
    _make_provision(
        name = "make_provision",
        out = "otrp_pkg",
        sd_privilege = "sd.privilege",
        **kwargs
    )
    register_cmd_provision(**kwargs)
    _register_cmd_launch(
        name = "launch_qemu",
        sh_exec = "ssh",
        sh_opts = "-o StrictHostKeyChecking=no",
        sh_host = "root@192.168.3.53",
        **kwargs
    )
    _register_cmd_launch(
        name = "launch_android",
        sh_exec = "adb",
        sh_opts = "",
        sh_host = "shell",
        **kwargs
    )
