load(":utils.bzl", "get_dynamic_library_linking_inputs")


def _get_static_linker_inputs(target, deps):
    inputs_set = get_dynamic_library_linking_inputs(target)

    deps_cc_infos = []
    for dep in deps:
        deps_cc_infos.append(dep[CcInfo])

    merged_cc_info = cc_common.merge_cc_infos(cc_infos = deps_cc_infos)

    static_linker_input_owners_set = {}
    for linker_input in merged_cc_info.linking_context.linker_inputs.to_list():
        owner = linker_input.owner
        for library in linker_input.libraries:
            if _is_input([library.static_library, library.pic_static_library] +library.objects  + library.pic_objects, inputs_set):
                static_linker_input_owners_set[str(owner)] = True

    return static_linker_input_owners_set.keys()

def _is_input(files, inputs_set):
    for file in files:
        if file and file.path in inputs_set:
            return True
    return False


_StaticLinkerInputs = provider()

def _static_linker_inputs_aspect_impl(target, ctx):
    static_linker_inputs = _get_static_linker_inputs(target, ctx.rule.attr.deps)
    return _StaticLinkerInputs(
        static_linker_inputs = static_linker_inputs
    )

_static_linker_inputs_aspect = aspect(
    implementation = _static_linker_inputs_aspect_impl,
)

def _static_linker_inputs_impl(ctx):
    static_linker_inputs_file = ctx.actions.declare_file(ctx.label.name + "_static_linker_inputs.txt")
    str_builder = ["Owner:{}".format(ctx.label)]
    str_builder.append("\n".join(ctx.attr.target[0][_StaticLinkerInputs].static_linker_inputs))
    ctx.actions.write(content = "\n".join(str_builder), output = static_linker_inputs_file)
    return [
        DefaultInfo(files = depset([static_linker_inputs_file]))
    ]

static_linker_inputs = rule(
    implementation = _static_linker_inputs_impl,
    attrs = {
        "target": attr.label_list(aspects = [_static_linker_inputs_aspect])
    },
)
