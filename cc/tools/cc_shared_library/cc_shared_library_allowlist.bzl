load("@rules_testing//lib:analysis_test.bzl", "analysis_test")

def _same_package_or_above(label_a, label_b):
    if label_a.workspace_name != label_b.workspace_name:
        return False
    package_a_tokenized = label_a.package.split("/")
    package_b_tokenized = label_b.package.split("/")
    if len(package_b_tokenized) < len(package_a_tokenized):
        return False

    if package_a_tokenized[0] != "":
        for i in range(len(package_a_tokenized)):
            if package_a_tokenized[i] != package_b_tokenized[i]:
                return False

    return True

def _check_if_target_under_path(value, pattern):
    if pattern.workspace_name != value.workspace_name:
        return False
    if pattern.name == "__pkg__":
        return pattern.package == value.package
    if pattern.name == "__subpackages__":
        return _same_package_or_above(pattern, value)

    return pattern.package == value.package and pattern.name == value.name

def _cc_shared_library_allowlist_test_impl(env, target):
    static_deps_list = []
    for action in target.actions:
        for file in action.outputs.to_list():
            if file.basename == "{}_static_linker_inputs.txt".format(target.label.name):
                static_deps_list = [Label(line) for line in action.content.split("\n")[1:]]
                break

    libs_not_in_allowlist = []
    for static_dep in static_deps_list:
        found = False
        for allowlist_entry in env.ctx.attr._static_deps_allowlist:
            static_dep_path_label = target.label.relative(allowlist_entry)
            if _check_if_target_under_path(static_dep, static_dep_path_label):
                found = True
                break

        if not found:
            libs_not_in_allowlist.append(static_dep)

    libs_message = []
    different_repos = {}
    for lib_not_in_allowlist in libs_not_in_allowlist:
        different_repos[lib_not_in_allowlist.workspace_name] = True
        libs_message.append(str(lib_not_in_allowlist))


    static_deps_message = []
    for repo in different_repos:
        static_deps_message.append("        \"@" + repo + "//:__subpackages__\",")

    env.expect.where(detail="The following libraries are not in the allowlist:\n" +
         "\n".join(libs_message) + "\nTo update the allowlist " +
         "with the most coarse granularity add the following entries:\n" +
         "\n".join(static_deps_message)).that_int(len(libs_not_in_allowlist)).equals(0)


def _cc_shared_library_allowlist_test_macro(name, target, static_deps_allowlist):
    analysis_test(
        name = name,
        impl = _cc_shared_library_allowlist_test_impl,
        target = target,
        attrs = {
            "_static_deps_allowlist": attr.string_list(default = static_deps_allowlist),
        },
    )

cc_shared_library_allowlist_test = _cc_shared_library_allowlist_test_macro
