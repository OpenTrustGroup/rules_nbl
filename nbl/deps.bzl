load(
    "@io_bazel_rules_nbl//nbl/private:repositories.bzl",
    _nbl_rules_dependencies = "nbl_rules_dependencies",
)
load(
    "@io_bazel_rules_nbl//nbl/private:sdk.bzl",
    _nbl_register_libraries = "nbl_register_libraries",
    _nbl_register_sdk = "nbl_register_sdk",
)

nbl_rules_dependencies = _nbl_rules_dependencies
nbl_register_libraries = _nbl_register_libraries
nbl_register_sdk = _nbl_register_sdk
