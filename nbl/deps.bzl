load(
    "@io_bazel_rules_nbl//nbl/private:repositories.bzl",
    _nbl_rules_dependencies = "nbl_rules_dependencies",
)
load(
    "@io_bazel_rules_nbl//nbl/private:sdk.bzl",
    _nbl_register_toolchains = "nbl_register_toolchains",
)

nbl_rules_dependencies = _nbl_rules_dependencies
nbl_register_toolchains = _nbl_register_toolchains
