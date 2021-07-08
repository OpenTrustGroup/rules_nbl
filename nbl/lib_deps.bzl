#Copyright 2021 GoldenRiver Technologies Co., Ltd.All rights reserved.

NEBULA_ASYNC_DEPS = [
    "@nbl_sdk//hee/async",
    "@nbl_sdk//hee/async-cpp",
    "@nbl_sdk//hee/async-default",
    "@nbl_sdk//hee/async-loop",
    "@nbl_sdk//hee/async-loop-cpp",
]

NEBULA_FIDL_DEPS = [
    "@nbl_sdk//hee/component",
    "@nbl_sdk//hee/app",
    "@nbl_sdk//hee/fdio",
    "@nbl_sdk//hee/mem",
    "@nbl_sdk//hee/fidl",
    "@nbl_sdk//hee/fidl_cpp",
    "@nbl_sdk//hee/fs",
    "@nbl_sdk//hee/svc",
] + NEBULA_ASYNC_DEPS

NEBULA_LIB_DEPS = [
    "@nbl_sdk//hee/fsl",
    "@nbl_sdk//hee/fxl",
    "@nbl_sdk//hee/nebula-cpp",
    "@nbl_sdk//hee/pretty",
    "@nbl_sdk//hee/trusty",
    "@nbl_sdk//hee/zircon",
    "@nbl_sdk//hee/zlib",
] + NEBULA_FIDL_DEPS


NEBULA_APP_DEPS = [
    "@nbl_sdk//hee/nbl_ta_controller",
    "@nbl_sdk//hee/nbl_loader",
    "@nbl_sdk//hee/nbl_fwk_hee",
] + NEBULA_LIB_DEPS

NEBULA_DRV_DEPS = [
    # "@nbl_sdk//hee/boringssl",
    # "@nbl_sdk//hee/camproxy",
    "@nbl_sdk//hee/driver",
    "@nbl_sdk//hee/ddk",
    "@nbl_sdk//hee/ddktl",
    # "@nbl_sdk//hee/nbl_attest",
    # "@nbl_sdk//hee/nbl_fwk_hee",
    # "@nbl_sdk//hee/nbl_gui",
    # "@nbl_sdk//hee/nbl_qrcode",
    # "@nbl_sdk//hee/nbl_trace_provider",
    # "@nbl_sdk//hee/region-alloc",
    # "@nbl_sdk//hee/sync",
    # "@nbl_sdk//hee/trace-engine",
]
