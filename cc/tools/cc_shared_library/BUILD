load(":cc_shared_library_allowlist.bzl", "cc_shared_library_allowlist_test")

cc_shared_library(
    name = "foo_so",
    deps = [
        "@repo1//:foo",
    ]
)

cc_shared_library_allowlist_test(
    name = "test",
    target = ":foo_so",
    static_deps_allowlist = [
        "@repo1//:foo",
        "@repo1//:bar",
        "@repo1//:baz",
        "@repo1//:qux",
        "@repo1//:quux",
        "@repo2//:corge",
        "@repo2//:grault",
        "@repo2//:garply",
    ],
)