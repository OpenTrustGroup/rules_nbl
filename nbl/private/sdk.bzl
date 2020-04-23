load(
    "@io_bazel_rules_nbl//nbl/private:sdk_list.bzl",
    "DEFAULT_VERSION",
    "MIN_SUPPORTED_VERSION",
    "SDK_REPOSITORIES",
)

def _remote_sdk(ctx, urls, strip_prefix, sha256):
    ctx.download_and_extract(
        url = urls,
        stripPrefix = strip_prefix,
        sha256 = sha256,
    )

def _nbl_download_sdk_impl(ctx):
    sdks = SDK_REPOSITORIES[DEFAULT_VERSION]
    platform = "linux_amd64"
    filename, sha256 = sdks[platform]
    _sdk_build_file(ctx, platform)
    _remote_sdk(ctx, [url.format(filename) for url in ctx.attr.urls], ctx.attr.strip_prefix, sha256)

_nbl_download_sdk = repository_rule(
    _nbl_download_sdk_impl,
    attrs = {
        "sdks": attr.string_list_dict(),
        "urls": attr.string_list(default = ["http://gle43/components/{}"]),
        "version": attr.string(),
        "strip_prefix": attr.string(default = ""),
        "_clang": attr.string(default = "toolchains/clang"),
        "_sysroot": attr.string(default = "hee"),
        "_tools": attr.string(default = "host"),
    },
)

def nbl_download_sdk(name, **kwargs):
    _nbl_download_sdk(name = name, **kwargs)
    native.register_toolchains("@nbl_sdk//:clang_fuchsia_aarch64")

def _sdk_build_file(ctx, platform):
    ctx.file("ROOT")
    os, _, arch = platform.partition("_")
    ctx.template(
        "BUILD.bazel",
        Label("@io_bazel_rules_nbl//nbl/private:BUILD.sdk.bazel"),
        executable = False,
        substitutions = {
            "{os}": os,
            "{arch}": arch,
        },
    )
    ctx.template(
        "cc_toolchain_config.bzl",
        Label("@io_bazel_rules_nbl//nbl/private:cc_toolchain_config.bzl.tpl"),
        substitutions = {
            "%{SDK_COMPILER_PATH}%": str(ctx.path(ctx.attr._clang)),
            "%{SDK_SYSROOT_PATH}%": str(ctx.path(ctx.attr._sysroot)),
        },
    )

def nbl_register_toolchains():
    nbl_download_sdk(
        name = "nbl_sdk",
        strip_prefix = "sdk",
    )

def _nbl_lib_impl(ctx):
    ctx.symlink("../nbl_sdk/hee", "hee")
    ctx.template(
        "BUILD.bazel",
        Label("@io_bazel_rules_nbl//nbl/private:nbl_lib.bzl.tpl"),
    )

_nbl_lib = repository_rule(
    implementation = _nbl_lib_impl,
)

def nbl_register_libraries():
    _nbl_lib(name = "nbl_lib")
