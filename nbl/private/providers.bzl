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

NebulaSdk = provider(
    fields = [
        "name",
        "path",
        "otrp",
        "host",
    ],
)
