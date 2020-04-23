load("@io_bazel_rules_nbl//nbl/private:providers.bzl", "NebulaSdk")

def _nbl_toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(sdk = ctx.attr.sdk[NebulaSdk])]

nbl_toolchain = rule(
    _nbl_toolchain_impl,
    attrs = {
        "sdk": attr.label(
            mandatory = True,
            providers = [NebulaSdk],
            cfg = "exec",
            doc = "The SDK this toolchain is based on",
        ),
    },
    provides = [platform_common.ToolchainInfo],
)

# Declare a dummy toolchain used to keep "sdk" and used by rules
def declare_toolchains(sdk):
    toolchain_name = "nbl_toolchain_dummy"
    impl_name = toolchain_name + "-impl"
    nbl_toolchain(
        name = impl_name,
        sdk = sdk,
        tags = ["manual"],
        visibility = ["//visibility:public"],
    )
    native.toolchain(
        name = toolchain_name,
        toolchain_type = "@io_bazel_rules_nbl//nbl:toolchain",
        toolchain = ":" + impl_name,
    )
