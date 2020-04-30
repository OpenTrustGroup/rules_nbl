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

"""Define a dummy toolchain for other rules to access sdk info."""

load("@io_bazel_rules_nbl//nbl/private:providers.bzl", "NebulaSdkInfo")

def _nbl_toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(sdk = ctx.attr.sdk[NebulaSdkInfo])]

nbl_toolchain = rule(
    _nbl_toolchain_impl,
    attrs = {
        "sdk": attr.label(
            mandatory = True,
            providers = [NebulaSdkInfo],
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
