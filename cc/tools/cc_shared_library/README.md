The `cc_shared_library_allowlist_test` Bazel rule lets you create an allowlist
to control which targets get linked into your `cc_shared_library`, whenever
something not allowlisted gets linked, the test will fail.

It accepts the same syntax as `visibility` attributes, i.e. full target names,
//package-name:\_\_pkg\_\_ and //package-name:\_\_subpackages\_\_.
