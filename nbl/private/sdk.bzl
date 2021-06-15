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

"""Sdk helper and rules definitions"""

load(
    "@io_bazel_rules_nbl//nbl/private:sdk_list.bzl",
    "DEFAULT_VERSION",
    "SDK_REPOSITORIES",
)
load(
    "@io_bazel_rules_nbl//nbl/private:providers.bzl",
    "HostInfo",
    "NebulaSdkInfo",
    "OtrpInfo",
    "TargetInfo",
)

def _remote_sdk(ctx, urls, strip_prefix, sha256):
    if len(urls) == 0:
        fail("no urls specified")
    if strip_prefix != "":
        fail("strip_prefix not supported")
    ctx.download(
        url = urls,
        sha256 = sha256,
        output = "_sdk.tmp",
    )
    res = ctx.execute(["tar", "-xf", "_sdk.tmp", "--strip-components=1"])
    if res.return_code:
        fail("error extracting SDK:\n" + res.stdout + res.stderr)
    ctx.execute(["rm", "_sdk.tmp"])

def _nbl_download_sdk_impl(ctx):
    if ctx.attr.version:
        if ctx.attr.version not in SDK_REPOSITORIES:
            fail("unsupported sdk version: {}".format(ctx.attr.version))
        sdks = SDK_REPOSITORIES[ctx.attr.version]
    else:
        sdks = SDK_REPOSITORIES[DEFAULT_VERSION]
    platform = "linux_amd64"
    filename, sha256 = sdks[platform]
    _remote_sdk(ctx, [url.format(filename) for url in ctx.attr.urls], ctx.attr.strip_prefix, sha256)
    _sdk_build_file(ctx)

_nbl_download_sdk = repository_rule(
    _nbl_download_sdk_impl,
    attrs = {
        "urls": attr.string_list(default = ["http://gle43/components/{}"]),
        "version": attr.string(),
        "strip_prefix": attr.string(default = ""),
    },
)

def _detect_compiler_version(ctx, cc_path):
    res = ctx.execute(["ls", "{}/lib/clang/".format(cc_path)])
    if res.return_code == 0 and len(res.stdout.strip().split(".")) == 3:
        return res.stdout.strip()

    res = ctx.execute(["ls", "{}/lib/gcc/{}".format(cc_path)])
    if res.return_code == 0:
        cc_target = res.stdout.strip()
        res = ctx.execute(["ls", "{}/lib/gcc/{}/".format(cc_path, cc_target)])
        if res.return_code == 0 and len(res.stdout.strip().split(".")) == 3:
            return res.stdout.strip()

    fail("Could not detect compiler version")

def _detect_compiler_type(ctx, compiler_path):
    res = ctx.execute(["ls", "{}/bin/".format(compiler_path)])
    if res.return_code != 0:
        fail("Could not search compiler bin/")

    if res.stdout.find("clang") != -1:
        return "clang"

    if res.stdout.find("gcc") != -1:
        return "gcc"

    fail("Could not detect compiler type")

# HACK: For C++ header files, GCC access the real paths of file system
# instead of symlinks inside sandbox, so real paths are needed for
# cxx_builtin_include_directories in cc_config_*.bzl.tpl. To locate the
# GCC path, a manifest in toolchain root was used.
def _detect_gcc_realpath(ctx, compiler_path):
    res = ctx.execute(["find", "{}".format(compiler_path), "-name", "*manifest.txt"])
    if res.return_code != 0:
        fail("Could not find manifest.txt in GCC")

    res = ctx.execute(["realpath", "{}".format(res.stdout.strip())])
    if res.return_code != 0:
        fail("Could not locate realpath of manifest.txt")

    res = ctx.execute(["dirname", res.stdout.strip()])
    if res.return_code != 0:
        fail("Could not detect directory of GCC")

    return res.stdout.strip()

# NOTE: Supports Linaro/ARM toolchain sysroot only.
def _detect_sysroot_version(ctx, sysroot_path):
    res = ctx.execute(["ls", "{}/include/c++".format(sysroot_path)])
    if res.return_code == 0:
        if len(res.stdout.strip().split(".")) == 3:
            return res.stdout.strip()
    return ""

def _assert_eq(a, b):
    if a != b:
        fail("{} != {}".format(a, b))

def _gen_cc_config(ctx, cc_target, cc_path, gcc_path, sysroot_path):
    cc_type = _detect_compiler_type(ctx, cc_path)
    cc_version = _detect_compiler_version(ctx, cc_path)
    sysroot_version = _detect_sysroot_version(ctx, sysroot_path)

    # HACK: see _nbl_wrap_toolchain docs for detail.
    if gcc_path == "":
        _assert_eq(cc_target, "aarch64-linux-gnu")
        _assert_eq(cc_type, "clang")
        _assert_eq(cc_version, "7.0.0")
        gcc_path = sysroot_path
        sysroot_path = "{}/{}".format(gcc_path, cc_target)

    ctx.template(
        "cc_config-{}.bzl".format(cc_target),
        Label("@io_bazel_rules_nbl//nbl/private:cc_config_{}_{}_{}.bzl.tpl".format(cc_type, cc_version, cc_target)),
        substitutions = {
            "%{COMPILER_TARGET}%": cc_target,
            "%{COMPILER_PATH}%": str(ctx.path(cc_path)),
            "%{COMPILER_VERSION}%": cc_version,
            "%{GCC_TOOLCHAIN_PATH}%": str(ctx.path(gcc_path)),
            "%{SYSROOT_PATH}%": str(ctx.path(sysroot_path)),
            "%{SYSROOT_VERSION}%": sysroot_version,
        },
    )

def _wrap_build_file(ctx, cc_target, cc_path, sysroot_path):
    ctx.template(
        "BUILD.bazel",
        Label("@io_bazel_rules_nbl//nbl/private:BUILD.compiler.bazel"),
        substitutions = {
            "%{COMPILER_TARGET}%": cc_target,
        },
    )
    _gen_cc_config(ctx, cc_target, cc_path, "", sysroot_path)

def _sdk_build_file(ctx):
    ctx.file("ROOT")
    ctx.template(
        "BUILD.bazel",
        Label("@io_bazel_rules_nbl//nbl/private:BUILD.sdk.bazel"),
        executable = False,
        substitutions = {
            "%{SDK_NAME}%": ctx.name,
            "%{SDK_PATH}%": str(ctx.path(".")),
        },
    )

    _gen_cc_config(
        ctx,
        "aarch64-fuchsia",
        "toolchains/clang",
        "toolchains/linaro-gcc",
        "hee",
    )
    _gen_cc_config(
        ctx,
        "aarch64-linux-gnu",
        "toolchains/clang",
        "toolchains/linaro-gcc",
        "toolchains/linaro-gcc/aarch64-linux-gnu",
    )

def _nbl_lib_impl(ctx):
    ctx.symlink("../{}/hee".format(ctx.attr.sdk), "hee")
    ctx.template(
        "BUILD.bazel",
        Label("@io_bazel_rules_nbl//nbl/private:nbl_lib.bzl.tpl"),
    )

_nbl_lib = repository_rule(
    implementation = _nbl_lib_impl,
    attrs = {
        "sdk": attr.string(),
    },
)

def nbl_register_sdk(name = "nbl_sdk", version = None, path = None):
    """Register a local/remote sdk, libs and toolchains.

    Args:
      name: The sdk name, used as label to referenced in other rules.
      version: The sdk version. ex. 1.0.17.1, default: latest
      path: The absolute path to local sdk.
    """

    sdk_kinds = ("_nbl_download_sdk", "_nbl_local_sdk")
    existing_rules = native.existing_rules()
    sdk_rules = [r for r in existing_rules.values() if r["kind"] in sdk_kinds]
    if len(sdk_rules) > 0:
        fail("already have one sdk or toolchain registered.")

    if version and path:
        fail("version and path must not both be set")

    if path:
        _nbl_local_sdk(name = name, path = path)
    else:
        _nbl_download_sdk(name = name, version = version)

    native.register_toolchains("@{}//:{}".format(name, "aarch64-fuchsia"))
    native.register_toolchains("@{}//:{}".format(name, "aarch64-linux-gnu"))
    native.register_toolchains("@{}//:nbl_toolchain_dummy".format(name))

def _nbl_local_sdk_impl(ctx):
    for entry in ["android", "hee", "host", "ree", "run", "toolchains", "test_suite"]:
        ctx.symlink(ctx.attr.path + "/" + entry, entry)
    _sdk_build_file(ctx)

_nbl_local_sdk = repository_rule(
    _nbl_local_sdk_impl,
    attrs = {
        "path": attr.string(mandatory = True),
    },
)

def _nbl_sdk_impl(ctx):
    return [NebulaSdkInfo(
        name = ctx.attr.name,
        path = ctx.attr.path,
        otrp = OtrpInfo(
            provision_exe = ctx.file.otrp_provision_exe,
            keystore = ctx.file.otrp_keystore,
            suite = ctx.files.otrp_suite,
        ),
        host = HostInfo(
            create_archive_manifest = ctx.file.host_create_archive_manifest,
            far = ctx.file.host_far,
            fidlc = ctx.file.host_fidlc,
            fidlgen = ctx.file.host_fidlgen,
            nodejs = ctx.files.host_nodejs,
            css_validator_exe = ctx.file.css_validator_exe,
        ),
        target = TargetInfo(
            nblruncmd = ctx.file.target_nblruncmd,
        ),
    )]

nbl_sdk = rule(
    _nbl_sdk_impl,
    attrs = {
        "path": attr.string(),
        "otrp_provision_exe": attr.label(allow_single_file = True, mandatory = True),
        "otrp_keystore": attr.label(allow_single_file = True, mandatory = True),
        "otrp_suite": attr.label(allow_files = True, mandatory = True),
        "host_create_archive_manifest": attr.label(allow_single_file = True, mandatory = True),
        "host_far": attr.label(allow_single_file = True, mandatory = True),
        "host_fidlc": attr.label(allow_single_file = True, mandatory = True),
        "host_fidlgen": attr.label(allow_single_file = True, mandatory = True),
        "host_nodejs": attr.label(allow_files = True, mandatory = True),
        "css_validator_exe": attr.label(allow_single_file = True, mandatory = True),
        "target_nblruncmd": attr.label(allow_single_file = True, mandatory = True),
    },
    provides = [NebulaSdkInfo],
)

def nbl_wrap_toolchain(name, target, compiler, sysroot):
    # TODO:  prevent > 1 toolchain registered for same target
    _nbl_wrap_toolchain(name = name, target = target, compiler = compiler, sysroot = sysroot)
    native.register_toolchains("@{}//:{}".format(name, target))

def _nbl_wrap_toolchain_impl(ctx):
    compiler_path = str(ctx.path(ctx.attr.compiler).dirname)
    for entry in ["bin", "include", "lib", "share"]:
        ctx.symlink(compiler_path + "/" + entry, entry)
    sysroot_path = str(ctx.path(ctx.attr.sysroot).dirname)
    _wrap_build_file(ctx, ctx.attr.target, compiler_path, sysroot_path)

_nbl_wrap_toolchain = repository_rule(
    _nbl_wrap_toolchain_impl,
    attrs = {
        "target": attr.string(mandatory = True),
        "compiler": attr.label(mandatory = True),
        "sysroot": attr.label(
            mandatory = True,
            doc = "For clang7, sysroot must be GCC toolchain label for --gcc-toolchain.",
        ),
    },
)
