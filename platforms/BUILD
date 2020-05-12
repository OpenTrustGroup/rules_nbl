# Defines a custom platform with a new CPU type.
#
# This is only necessary when you want to build for custom platforms (by
# building with the --platforms flag). By default Bazel targets the
# machine Bazel runs on, which is modeled with the auto-configured
# platform "@local_config_platform//:host".

constraint_setting(name = "target")

constraint_value(
    name = "aarch64-fuchsia",
    constraint_setting = "target",
    visibility = ["//visibility:public"],
)

constraint_value(
    name = "aarch64-linux-gnu",
    constraint_setting = "target",
    visibility = ["//visibility:public"],
)

config_setting(
    name = "fuchsia",
    constraint_values = [
        ":aarch64-fuchsia",
    ],
    visibility = ["//visibility:public"],
)

config_setting(
    name = "linux",
    constraint_values = [
        ":aarch64-linux-gnu",
    ],
    visibility = ["//visibility:public"],
)

platform(
    name = "nebula_arm64",
    constraint_values = [
        "@platforms//cpu:arm64",
        ":aarch64-fuchsia",
    ],
)

platform(
    name = "linux_arm64",
    constraint_values = [
        "@platforms//cpu:arm64",
        ":aarch64-linux-gnu",
    ],
)
