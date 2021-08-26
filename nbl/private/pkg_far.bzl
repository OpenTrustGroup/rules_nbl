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
    "nbl_register_pkgcmds",
)
load(
    "@io_bazel_rules_nbl//nbl/private:providers.bzl",
    "PackageInfo",
)

def _pkg_far_impl(ctx):
    toolchain = ctx.toolchains["@io_bazel_rules_nbl//nbl:toolchain"]
    sdk = toolchain.sdk
    create_archive_manifest = sdk.host.create_archive_manifest
    css_validator = sdk.host.css_validator_exe
    nodejs = sdk.host.nodejs
    far = sdk.host.far

    data_files = []
    for f in ctx.files.private_data:
        src_path = f.path
        dst_path = "data/" + f.basename
        data_files.append("%s=%s" % (dst_path, src_path))

    for f in ctx.files.drivers:
        src_path = f.path
        dst_path = "drivers/" + f.basename
        data_files.append("%s=%s" % (dst_path, src_path))

    for f in ctx.files.libraries:
        if (f.path.endswith(".so")):
            src_path = f.path
            dst_path = "lib/" + f.basename
            data_files.append("%s=%s" % (dst_path, src_path))

    for f in ctx.files.services:
        src_path = f.path
        dst_path = "services/" + f.basename
        data_files.append("%s=%s" % (dst_path, src_path))

    for f in ctx.files.tests:
        src_path = f.path
        dst_path = "tests/" + f.basename
        data_files.append("%s=%s" % (dst_path, src_path))

    resources_files = []
    for key, value in ctx.attr.resources.items():
        resource_file = key.files.to_list()[0]
        src_path = resource_file.path
        resources_files.append(resource_file)
        dst_path = "resources/" + value
        data_files.append("%s=%s" % (dst_path, src_path))

    additional_deps = []
    if len(ctx.files.private_data) > 0:
        staging_file = ctx.actions.declare_file("css_validate_complete." + ctx.attr.name)

        input_dir = ctx.files.private_data[0].dirname
        ctx.actions.run(
            inputs = ctx.files.private_data,
            arguments = ["-i", input_dir, "-o", staging_file.path],
            executable = css_validator,
            outputs = [staging_file],
            tools = nodejs,
        )
        additional_deps.append(staging_file)

    archive_manifest = ctx.actions.declare_file("archive_manifest." + ctx.attr.name)

    # create_archive_manifest -o MANIFEST -p . -e EXEC -a "data/data1=data/data1, data/data2=data/data2"
    ctx.actions.run(
        inputs = ctx.files.private_data + [ctx.file.exec, ctx.file.meta] + additional_deps,
        arguments = ["-p", ctx.label.package, "-o", archive_manifest.path, "-e", ctx.file.exec.path, "-a", ",".join(data_files)],
        executable = create_archive_manifest,
        outputs = [archive_manifest],
    )

    # far create --archive=FAR --manifest=MANIFEST
    additional_files = ctx.files.services + ctx.files.drivers + ctx.files.libraries + ctx.files.tests + resources_files
    ctx.actions.run(
        inputs = ctx.files.private_data + additional_files + [ctx.file.exec, ctx.file.meta, archive_manifest],
        arguments = ["create", "--archive=" + ctx.outputs.out.path, "--manifest=" + archive_manifest.path],
        executable = far,
        outputs = [ctx.outputs.out],
    )
    return [PackageInfo(exec = ctx.file.exec)]

_pkg_far = rule(
    implementation = _pkg_far_impl,
    attrs = {
        "exec": attr.label(allow_single_file = True, mandatory = True),
        "services": attr.label_list(allow_files = True),
        "tests": attr.label_list(allow_files = True),
        "resources": attr.label_keyed_string_dict(allow_files = True),
        "drivers": attr.label_list(allow_files = True),
        "libraries": attr.label_list(allow_files = True),
        "private_data": attr.label_list(allow_files = True),
        "meta": attr.label(allow_single_file = True),
        "out": attr.output(),
    },
    toolchains = ["@io_bazel_rules_nbl//nbl:toolchain"],
)

def pkg_far(**kwargs):
    kwargs["name"] = kwargs["name"] if "name" in kwargs else "default"
    meta = kwargs.get("meta") or "meta/sandbox"

    _pkg_far(out = kwargs["name"] + ".far", meta = meta, **kwargs)
    nbl_register_pkgcmds(":" + kwargs["name"], name = kwargs["name"])
