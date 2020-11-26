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

"""FIDL helper and rules for use in projects BUILD files."""

def _fidl_impl(ctx):
    toolchain = ctx.toolchains["@io_bazel_rules_nbl//nbl:toolchain"]
    sdk = toolchain.sdk
    fidlc = sdk.host.fidlc
    fidlgen = sdk.host.fidlgen
    name = ctx.attr.name.split(".")[0]

    out_cc = ctx.outputs.out_cc
    out_h = ctx.outputs.out_h
    out_table = ctx.outputs.out_table
    out_json = ctx.actions.declare_file(name + ".json")

    ctx.actions.run(
        inputs = ctx.files.sources,
        arguments = [
            "--tables", out_table.path,
            "--json", out_json.path,
            "--name", name,
            "--files",
        ] + [f.path for f in ctx.files.sources],
        executable = fidlc,
        outputs = [out_json, out_table],
    )

    ctx.actions.run(
        inputs = [out_json, out_table],
        arguments = [
            "--json", out_json.path,
            "--output-base", out_cc.dirname + "/" + name,
            "--include-base", out_cc.dirname + "/../../",
            "--generators", "cpp",
        ],
        executable = fidlgen,
        outputs = [out_cc, out_h],
    )

_fidl = rule(
    implementation = _fidl_impl,
    attrs = {
        "sources": attr.label_list(allow_files = True),
        "out_cc": attr.output(),
        "out_h": attr.output(),
        "out_table": attr.output(),
    },
    toolchains = ["@io_bazel_rules_nbl//nbl:toolchain"],
)

def fidl(name, sources):
    out_cc = "fuchsia/cpp/" + name + ".cc"
    out_h = "fuchsia/cpp/" + name + ".h"
    out_table = "fuchsia/cpp/" + name + ".tables.cc"
    _fidl(name = name + ".gen", out_cc = out_cc, out_h = out_h, out_table = out_table, sources = sources)

    native.cc_library(
        name = name,
        srcs = [
            out_cc, out_table
        ],
        hdrs = [
            out_h
        ],
        data = [
            ":%s.gen" % name,
        ],
        deps = [
            "@nbl_sdk//hee/fidl_cpp",
            "@nbl_sdk//hee/fidl",
            "@nbl_sdk//hee/async",
            "@nbl_sdk//hee/async-default",
            "@nbl_sdk//hee/async-loop",
            "@nbl_sdk//hee/fdio",
        ],
        strip_include_prefix = ".",
        visibility = ["//visibility:public"],
    )
