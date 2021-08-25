load(
    "@io_bazel_rules_nbl//nbl/private:providers.bzl",
    "OtrpInfo",
)

def _external_otrp_keystore_impl(ctx):
    return OtrpInfo(keystore = ctx.build_setting_value)

external_otrp_keystore = rule(
    implementation = _external_otrp_keystore_impl,
    build_setting = config.string(flag = True),
)
