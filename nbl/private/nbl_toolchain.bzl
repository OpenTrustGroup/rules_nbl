load("@io_bazel_rules_nbl//nbl/private:providers.bzl", "NblSDK")

def _nbl_toolchain_impl(ctx):
    sdk = ctx.attr.sdk[NblSDK]
    print(sdk)
    print(ctx)
    #native.cc_toolchain(
    #    name = "aa",
    #    all_files = sdk.clang,
    #    compiler_files = "",
    #    dwp_files = "",
    #    linker_files = "",
    #    objcopy_files = "",
    #    strip_files = "",
    #    toolchain_config = "",
    #)

nbl_toolchain = rule(
    _nbl_toolchain_impl,
    attrs = {
        "sdk": attr.label(
            mandatory = True,
            providers = [NblSDK],
            cfg = "exec",
            doc = "The SDK this toolchain is based on",
        ),
    },
    provides = [platform_common.ToolchainInfo],
)

def declare_toolchains(host, sdk, builder = None):
    print(sdk)
    toolchain_name = "clang_nbl_aarch64"
    impl_name = toolchain_name + "-impl"
    nbl_toolchain(
        name = impl_name,
        sdk = sdk,
        tags = ["manual"],
        visibility = ["//visibility:public"],
    )
    native.toolchain(
        name = toolchain_name,
        #toolchain_type = "@io_bazel_rules_nbl//nbl:toolchain",
        toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
        exec_compatible_with = [
            "@bazel_tools//platforms:linux",
            "@bazel_tools//platforms:x86_64",
        ],
        target_compatible_with = [
            "@platforms//cpu:arm64",
        ],
        toolchain = ":" + impl_name,
    )
