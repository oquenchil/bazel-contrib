package(default_visibility = ["//visibility:public"])

exports_files(["foo.lds"])

cc_library(
    name = "foo",
    srcs = ["foo.cc"],
    hdrs = ["foo.h"],
    deps = [
        ":bar",
    ],
)

cc_library(
    name = "bar",
    srcs = ["bar.cc"],
    hdrs = ["bar.h"],
    deps = [
        ":baz",
    ],
)

cc_library(
    name = "baz",
    srcs = ["baz.cc"],
    hdrs = ["baz.h"],
    deps = [
        ":qux",
    ],
)

cc_library(
    name = "qux",
    srcs = ["qux.cc"],
    hdrs = ["qux.h"],
    deps = [
        ":quux",
    ],
)

cc_library(
    name = "quux",
    srcs = ["quux.cc"],
    hdrs = ["quux.h"],
    deps = [
        "@repo2//:corge",
    ],
)
