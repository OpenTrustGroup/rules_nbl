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

"""Package (FAR) helper and rules for use in projects BUILD files."""

load(
    "@io_bazel_rules_nbl//nbl/private:pkg_cmd.bzl",
    nbl_register_pkgcmds = "nbl_register_pkgcmds",
)

load(
    "@io_bazel_rules_nbl//nbl/private:providers.bzl",
    "PackageInfo",
)

def _pkg_far_impl(ctx):
    toolchain = ctx.toolchains["@io_bazel_rules_nbl//nbl:toolchain"]
    sdk = toolchain.sdk
    create_archive_manifest = sdk.host.create_archive_manifest
    far = sdk.host.far

    data_files = []
    for f in ctx.files.data:
        # The original f.path looks like 'hello_far/data/data3',
        # and by design the manifest needs 'data/data3', so remove hello_far/'.
        src_path = f.path
        dst_path = f.path[len(ctx.label.package) + 1:]
        data_files.append("%s=%s" % (dst_path, src_path))

    for f in ctx.files.drivers:
        src_path = f.path
        dst_path = "drivers/" + f.basename
        data_files.append("%s=%s" % (dst_path, src_path))

    for f in ctx.files.libraries:
        src_path = f.path
        dst_path = "lib/" + f.basename
        data_files.append("%s=%s" % (dst_path, src_path))

    archive_manifest = ctx.actions.declare_file("archive_manifest")

    # create_archive_manifest -o MANIFEST -p . -e EXEC -a "data/data1=data/data1, data/data2=data/data2"
    ctx.actions.run(
        inputs = ctx.files.data + [ctx.file.exec, ctx.file.meta, ctx.file.rscs],
        arguments = ["-p", ctx.label.package, "-o", archive_manifest.path, "-e", ctx.file.exec.path, "-a", ",".join(data_files)],
        executable = create_archive_manifest,
        outputs = [archive_manifest],
    )

    # far create --archive=FAR --manifest=MANIFEST
    ctx.actions.run(
        inputs = ctx.files.data + ctx.files.drivers + ctx.files.libraries + [ctx.file.exec, ctx.file.meta, ctx.file.rscs, archive_manifest],
        arguments = ["create", "--archive=" + ctx.outputs.out.path, "--manifest=" + archive_manifest.path],
        executable = far,
        outputs = [ctx.outputs.out],
    )
    return [PackageInfo(exec = ctx.file.exec)]

_pkg_far = rule(
    implementation = _pkg_far_impl,
    attrs = {
        "exec": attr.label(allow_single_file = True, mandatory = True),
        "drivers": attr.label_list(allow_files = True),
        "libraries": attr.label_list(allow_files = True),
        "data": attr.label_list(allow_files = True),
        "meta": attr.label(allow_single_file = True),
        "rscs": attr.label(allow_single_file = True),
        "out": attr.output(),
    },
    toolchains = ["@io_bazel_rules_nbl//nbl:toolchain"],
)

def pkg_far(**kwargs):
    kwargs["name"] = kwargs["name"] if "name" in kwargs else "default"
    meta = kwargs.get("meta") or "meta/sandbox"
    rscs = kwargs.get("rscs") or "resources/manifest.json"
    _pkg_far(out = kwargs["name"] + ".far", meta = meta, rscs = rscs, **kwargs)
    nbl_register_pkgcmds(":" + kwargs["name"], name = kwargs["name"])
