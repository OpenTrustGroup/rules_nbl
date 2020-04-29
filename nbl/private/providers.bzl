PackageInfo = provider(fields = ["exec"])

SdkOtrp = provider(
    fields = [
        "provision_exe",
        "keystore",
        "suite",
    ],
)

SdkHost = provider(
    fields = [
        "create_archive_manifest",
        "far",
    ],
)

SdkTarget = provider(
    fields = [
        "nblruncmd",
    ],
)

NebulaSdk = provider(
    fields = [
        "name",
        "path",
        "otrp",
        "host",
        "target",
    ],
)

OtrpParams = provider(
    doc = "Contains parameters of Otrp commands",
    fields = {
        "substitutions": "The key=val pairs (dict) used for scripts substitution",
        "runfiles": "The necessary files used for running scripts",
    },
)
