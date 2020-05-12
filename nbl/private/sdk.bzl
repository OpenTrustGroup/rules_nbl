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
    if urls[0].endswith(".tar.gz") or urls[0].endswith(".tar.xz"):
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
    else:
        ctx.download_and_extract(
            url = urls,
            stripPrefix = strip_prefix,
            sha256 = sha256,
        )

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
        "sdks": attr.string_list_dict(),
        "urls": attr.string_list(default = ["http://gle43/components/{}"]),
        "version": attr.string(),
        "strip_prefix": attr.string(default = ""),
    },
)

def _detect_compiler_version(ctx, compiler_path, compiler_target):
    #$CLANG_ROOT/lib/clang/10.0.0
    res = ctx.execute(["ls", "{}/lib/clang/".format(compiler_path)])
    if res.return_code == 0:
        if len(res.stdout.strip().split(".")) == 3:
            return res.stdout.strip()
        fail("Clang version not found")

    #$GCC_ROOT/lib/gcc/aarch64-linux-gnu/6.2.1
    res = ctx.execute(["ls", "{}/lib/gcc/{}/".format(compiler_path, compiler_target)])
    if res.return_code == 0:
        if len(res.stdout.strip().split(".")) == 3:
            return res.stdout.strip()
        fail("Gcc version not found")

    fail("Could not detect compiler version")

def _detect_compiler_type(ctx, compiler_path, compiler_target):
    res = ctx.execute(["ls", "{}/bin/{}-gcc".format(compiler_path, compiler_target)])
    if res.return_code == 0:
        return "gcc"

    res = ctx.execute(["ls", "{}/bin/clang".format(compiler_path)])
    if res.return_code == 0:
        return "clang"

    fail("Could not detect compiler type")

# NOTE: Supports Linaro/ARM toolchain sysroot only.
def _detect_sysroot_cpp_version(ctx, sysroot_path):
    res = ctx.execute(["ls", "{}/include/c++".format(sysroot_path)])
    if res.return_code == 0:
        if len(res.stdout.strip().split(".")) == 3:
            return res.stdout.strip()
        fail("Sysroot C++ version not found")
    fail("Could not detect sysroot c++ version")

def _cc_build_file(ctx, compiler_target, compiler_path, sysroot_path):
    compiler_type = _detect_compiler_type(ctx, compiler_path, compiler_target)
    compiler_version = _detect_compiler_version(ctx, compiler_path, compiler_target)
    sysroot_cpp_version = _detect_sysroot_cpp_version(ctx, sysroot_path)

    print(compiler_type)
    print(compiler_version)
    print(sysroot_cpp_version)

    ctx.template(
        "BUILD.bazel",
        Label("@io_bazel_rules_nbl//nbl/private:BUILD.compiler.bazel"),
        substitutions = {
            "%{COMPILER_TARGET}%": compiler_target,
        },
    )
    ctx.template(
        "cc_toolchain_config.bzl",
        Label("@io_bazel_rules_nbl//nbl/private:cc_config_{}_{}_{}.bzl.tpl".format(compiler_type, compiler_version, compiler_target)),
        substitutions = {
            "%{COMPILER_TARGET}%": compiler_target,
            "%{COMPILER_PATH}%": str(ctx.path(compiler_path)),
            "%{COMPILER_VERSION}%": compiler_version,
            "%{SYSROOT_PATH}%": str(ctx.path(sysroot_path)),
            "%{SYSROOT_CPP_VERSION}%": sysroot_cpp_version,
        },
    )

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
      version: The sdk version. ex. 1.0.17.1
      path: The absolute path to local sdk.
    """

    sdk_kinds = ("_nbl_download_sdk", "_nbl_local_sdk", "_nbl_local_cc")
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

    print("nbl_register_sdk %s" % path)
    compiler_target = "aarch64-fuchsia"
    compiler_path = "../{}/toolchains/clang".format(name)
    sysroot_path = "../{}/hee".format(name)

    #compiler_path = "@{}//:compiler_path"
    #sysroot_path = "@{}//:sysroot_path"
    nbl_register_toolchain(compiler_target + "_cc", compiler_target, compiler_path, sysroot_path)

    # TODO: support compiler "aarch64-linux-gnu" registration for sdk

    _nbl_lib(name = name + "_lib", sdk = name)
    native.register_toolchains("@{}//:nbl_toolchain_dummy".format(name))

def _nbl_local_sdk_impl(ctx):
    for entry in ["android", "hee", "host", "ree", "run", "toolchains"]:
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
        "target_nblruncmd": attr.label(allow_single_file = True, mandatory = True),
    },
    provides = [NebulaSdkInfo],
)

def nbl_register_toolchain(name, target, compiler_path, sysroot_path):
    # TODO:  prevent > 1 toolchain registered for same target
    _nbl_cc_toolchain(name = name, target = target, compiler = compiler_path, sysroot = sysroot_path)
    native.register_toolchains("@{}//:{}".format(name, target))

def _nbl_cc_toolchain_impl(ctx):
    for entry in ["bin", "include", "lib", "libexec", "share"]:
        ctx.symlink(ctx.attr.compiler + "/" + entry, entry)
    _cc_build_file(ctx, ctx.attr.target, ctx.attr.compiler, ctx.attr.sysroot)

_nbl_cc_toolchain = repository_rule(
    _nbl_cc_toolchain_impl,
    attrs = {
        "target": attr.string(mandatory = True),
        "compiler": attr.string(mandatory = True),
        "sysroot": attr.string(mandatory = True),
    },
)
