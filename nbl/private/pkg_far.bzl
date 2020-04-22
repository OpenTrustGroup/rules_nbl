load(
    "@io_bazel_rules_nbl//nbl/private:providers.bzl",
    "PackageInfo",
)

def _pkg_far_impl(ctx):
    data_files = []
    for f in ctx.files.data:
        if f.path.startswith(ctx.label.package):
            # remove "//package_path" and trailing "/"
            src_path = f.path
            dst_path = f.path[len(ctx.label.package) + 1:]
            data_files.append("%s=%s" % (dst_path, src_path))
        else:
            print("%s not startswith %s, ignored" % (f.path, ctx.label.package))

    archive_manifest = ctx.actions.declare_file("archive_manifest")

    # create_archive_manifest -o MANIFEST -p . -e EXEC -a "data/data1=data/data1, data/data2=data/data2"
    ctx.actions.run(
        inputs = ctx.files.data + [ctx.file.exec, ctx.file.meta, ctx.file.rscs],
        arguments = ["-p", ctx.label.package, "-o", archive_manifest.path, "-e", ctx.file.exec.path, "-a", ",".join(data_files)],
        executable = ctx.executable.create_archive_manifest,
        outputs = [archive_manifest],
    )

    # far create --archive=FAR --manifest=MANIFEST
    ctx.actions.run(
        inputs = ctx.files.data + [ctx.file.exec, ctx.file.meta, ctx.file.rscs, archive_manifest],
        arguments = ["create", "--archive=" + ctx.outputs.out.path, "--manifest=" + archive_manifest.path],
        executable = ctx.executable.far,
        outputs = [ctx.outputs.out],
    )
    return [PackageInfo(exec = ctx.file.exec)]

_real_pkg_far = rule(
    implementation = _pkg_far_impl,
    attrs = {
        "exec": attr.label(allow_single_file = True, mandatory = True),
        "data": attr.label_list(allow_files = True),
        "meta": attr.label(allow_single_file = True),
        "rscs": attr.label(allow_single_file = True),
        "create_archive_manifest": attr.label(
            default = Label("@nbl_sdk//:create_archive_manifest"),
            cfg = "host",
            executable = True,
            allow_files = True,
        ),
        "far": attr.label(
            default = Label("@nbl_sdk//:far"),
            cfg = "host",
            executable = True,
            allow_files = True,
        ),
        "out": attr.output(),
    },
)

def pkg_far(**kwargs):
    meta = kwargs.get("meta") or "meta/sandbox"
    rscs = kwargs.get("rscs") or "resources/manifest.json"
    _real_pkg_far(out = kwargs["name"] + ".far", meta = meta, rscs = rscs, **kwargs)
