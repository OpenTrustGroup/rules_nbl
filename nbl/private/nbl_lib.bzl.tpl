
cc_library(
    name = "zlib",
    srcs = [ "zlib/lib/libz.so" ],
    hdrs = glob([
        "zlib/include/*.h"
    ]),
    strip_include_prefix = "zlib/include",
    visibility = [ "//visibility:public" ]
)

cc_library(
    name = "camproxy",
    srcs = [ "camproxy/lib/libcamproxy.a" ],
    hdrs = [
        "camproxy/include/camproxy/seccamlib.h",
    ],
    strip_include_prefix = "camproxy/include",
    visibility = [ "//visibility:public" ]
)

cc_library(
    name = "trusty",
    srcs = [
      "trusty/lib/liblibc-trusty.a",
      "trusty/lib/libstorage.a",
    ],
    hdrs = glob([
        "trusty/include/**/*.h",
    ]),
    strip_include_prefix = "trusty/include",
    visibility = [ "//visibility:public" ]
)

cc_library(
    name = "mtee_api",
    srcs = [ "trusty/lib/libmtee_api.a" ],
    visibility = [ "//visibility:public" ]
)

cc_library(
    name = "nbl_fwk",
    srcs = [ "nbl_fwk_hee/lib/libnbl_fwk_hee.a" ],
    hdrs = glob([
        "nbl_fwk_hee/include/**/*.h",
    ]),
    strip_include_prefix = "nbl_fwk_hee/include",
    visibility = [ "//visibility:public" ]
)

cc_library(
    name = "nbl_attest",
    srcs = [ "nbl_attest/lib/libnbl_attest.a" ],
    hdrs = glob([
        "nbl_attest/include/**/*.h",
    ]),
    strip_include_prefix = "nbl_attest/include",
    visibility = [ "//visibility:public" ]
)

cc_library(
    name = "nbl_trace_provider",
    srcs = [ "nbl_trace_provider/lib/libnbl_trace_provider.so" ],
    hdrs = glob([
        "nbl_trace_provider/include/**/*.h",
    ]),
    strip_include_prefix = "nbl_trace_provider/include",
    visibility = [ "//visibility:public" ]
)

cc_library(
    name = "trace",
    srcs = [
        "lib/libtrace.a",
        "lib/libtrace-engine.a",
        "lib/libzx.a",
        "lib/libfbl.a",
    ],
    hdrs = glob([
        "include/trace/*.h",
        "include/lib/zx/*.h",
        "include/fbl/*.h"
    ]),
    strip_include_prefix = "include",
    visibility = [ "//visibility:public" ]
)

cc_library(
    name = "boringssl",
    srcs = [
        "boringssl/lib/libcrypto.so",
    ],
    hdrs = glob([
        "boringssl/include/**/*.h",
    ]),
    strip_include_prefix = "boringssl/include",
    visibility = [ "//visibility:public" ]
)

cc_library(
    name = "keymaster",
    srcs = [
        "trusty/trusty/user/base/lib/keymaster/lib/libkeymaster.a",
    ],
    hdrs = glob([
        "trusty/trusty/user/base/lib/keymaster/include/**/*.h",
    ]),
    strip_include_prefix = "trusty/trusty/user/base/lib/keymaster/include",
    visibility = [ "//visibility:public" ]
)

cc_library(
    name = "keymaster_interface",
    hdrs = glob([
        "trusty/trusty/user/base/interface/keymaster/include/**/*.h",
    ]),
    strip_include_prefix = "trusty/trusty/user/base/interface/keymaster/include",
    visibility = [ "//visibility:public" ]
)
