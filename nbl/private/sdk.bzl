load(
    "@io_bazel_rules_nbl//nbl/private:sdk_list.bzl",
    "DEFAULT_VERSION",
    "MIN_SUPPORTED_VERSION",
    "SDK_REPOSITORIES",
)
load(
    "@io_bazel_rules_nbl//nbl/private:providers.bzl",
    "NebulaSdk",
    "SdkHost",
    "SdkOtrp",
)
load(
    "@io_bazel_rules_nbl//nbl/private:nbl_toolchain.bzl",
    "declare_toolchains",
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
    },
)

def _sdk_build_file(ctx, platform):
    ctx.file("ROOT")
    os, _, arch = platform.partition("_")
    ctx.template(
        "BUILD.bazel",
        Label("@io_bazel_rules_nbl//nbl/private:BUILD.sdk.bazel"),
        executable = False,
        substitutions = {
            "%{SDK_NAME}%": ctx.name,
            "%{SDK_PATH}%": str(ctx.path(".")),
        },
    )
    ctx.template(
        "cc_toolchain_config.bzl",
        Label("@io_bazel_rules_nbl//nbl/private:cc_toolchain_config.bzl.tpl"),
        substitutions = {
            "%{SDK_COMPILER_PATH}%": str(ctx.path("toolchains/clang")),
            "%{SDK_SYSROOT_PATH}%": str(ctx.path("hee")),
        },
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

def nbl_register_sdk(name = "nbl_sdk", path = None):
    sdk_kinds = ("_nbl_download_sdk", "_nbl_local_sdk")
    existing_rules = native.existing_rules()
    sdk_rules = [r for r in existing_rules.values() if r["kind"] in sdk_kinds]
    if len(sdk_rules) > 0:
        fail("already have one sdk registered.")

    if path:
        _nbl_local_sdk(name = name, path = path)
    else:
        _nbl_download_sdk(name = name, strip_prefix = "sdk")

    native.register_toolchains("@{}//:clang_fuchsia_aarch64".format(name))
    native.register_toolchains("@{}//:nbl_toolchain_dummy".format(name))

def _nbl_local_sdk_impl(ctx):
    platform = "linux_amd64"
    _sdk_build_file(ctx, platform)
    for entry in ["hee", "host", "run", "toolchains"]:
        ctx.symlink(ctx.attr.path + "/" + entry, entry)

_nbl_local_sdk = repository_rule(
    _nbl_local_sdk_impl,
    attrs = {
        "path": attr.string(),
    },
)

def _nbl_sdk_impl(ctx):
    return [NebulaSdk(
        name = ctx.attr.name,
        path = ctx.attr.path,
        otrp = SdkOtrp(
            provision_exe = ctx.file.otrp_provision_exe,
            keystore = ctx.file.otrp_keystore,
            suite = ctx.files.otrp_suite,
        ),
        host = SdkHost(
            create_archive_manifest = ctx.file.host_create_archive_manifest,
            far = ctx.file.host_far,
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
    },
    provides = [NebulaSdk],
)
