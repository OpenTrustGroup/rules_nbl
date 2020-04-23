
cc_import(
    name = "zlib",
    shared_library = "hee/zlib/lib/libz.so",
    hdrs = glob([
        "hee/zlib/include/*.h"
    ]),
    visibility = [ "//visibility:public" ]
)

cc_import(
    name = "camproxy",
    static_library = "hee/camproxy/lib/libcamproxy.a",
    hdrs = [
        "hee/camproxy/include/camproxy/seccamlib.h",
    ],
    visibility = [ "//visibility:public" ]
)

cc_import(
    name = "trusty",
    static_library = "hee/trusty/lib/liblibc-trusty.a",
    hdrs = glob([
        "hee/trusty/include/**/*.h",
        "hee/include/**/*.h",
    ]),
    visibility = [ "//visibility:public" ]
)

cc_import(
    name = "mtee_api",
    static_library = "hee/trusty/lib/libmtee_api.a",
    visibility = [ "//visibility:public" ]
)

cc_import(
    name = "nbl_fwk",
    static_library = "hee/nbl_fwk_hee/lib/libnbl_fwk_hee.a",
    hdrs = glob([
        "hee/nbl_fwk_hee/include/**/*.h",
    ]),
    visibility = [ "//visibility:public" ]
)

filegroup(
    name = "cmake_toolchain",
    srcs = [
        "cmake/nebula.toolchain.cmake",
    ],
    visibility = [ "//visibility:public" ]
)
