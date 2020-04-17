workspace(name = "io_bazel_rules_nbl")

load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@io_bazel_rules_nbl//nbl:deps.bzl", "nbl_register_toolchains", "nbl_rules_dependencies")

nbl_rules_dependencies()

nbl_register_toolchains()
