
cc_library(
    name = "zlib",
    srcs = [ "hee/zlib/lib/libz.so" ],
    hdrs = glob([
        "hee/zlib/include/*.h"
    ]),
    strip_include_prefix = "hee/zlib/include",
    visibility = [ "//visibility:public" ]
)

cc_library(
    name = "camproxy",
    srcs = [ "hee/camproxy/lib/libcamproxy.a" ],
    hdrs = [
        "hee/camproxy/include/camproxy/seccamlib.h",
    ],
    strip_include_prefix = "hee/camproxy/include",
    visibility = [ "//visibility:public" ]
)

cc_library(
    name = "trusty",
    srcs = [ "hee/trusty/lib/liblibc-trusty.a" ],
    hdrs = glob([
        "hee/trusty/include/**/*.h",
    ]),
    strip_include_prefix = "hee/trusty/include",
    visibility = [ "//visibility:public" ]
)

cc_library(
    name = "mtee_api",
    srcs = [ "hee/trusty/lib/libmtee_api.a" ],
    visibility = [ "//visibility:public" ]
)

cc_library(
    name = "nbl_fwk",
    srcs = [ "hee/nbl_fwk_hee/lib/libnbl_fwk_hee.a" ],
    hdrs = glob([
        "hee/nbl_fwk_hee/include/**/*.h",
    ]),
    strip_include_prefix = "hee/nbl_fwk_hee/include",
    visibility = [ "//visibility:public" ]
)

cc_library(
    name = "nbl_trace_provider",
    srcs = [ "hee/nbl_trace_provider/lib/libnbl_trace_provider.so" ],
    hdrs = glob([
        "hee/nbl_trace_provider/include/**/*.h",
    ]),
    strip_include_prefix = "hee/nbl_trace_provider/include",
    visibility = [ "//visibility:public" ]
)

cc_library(
    name = "trace",
    srcs = [
        "hee/lib/libtrace.a",
        "hee/lib/libtrace-engine.a",
        "hee/lib/libzx.a",
        "hee/lib/libfbl.a",
    ],
    hdrs = glob([
        "hee/include/trace/*.h",
    ]),
    visibility = [ "//visibility:public" ]
)
