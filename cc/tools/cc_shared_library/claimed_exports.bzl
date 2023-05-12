"""

This is different to exports_finder in the sense that it will write to a
file all the targets that the cc_shared_library target claims to export during
the analysis phase.

These claims of exports are used to drive how the linking actions are set up
when multiple cc_shared_libraries are in the same build. However, they do not
necessarily match what the shared object actually exports. What the shared
object exports is controlled by the user via visibility script or visibility
declarations in source files (the contents of which Bazel doesn't look at)

"""

load(":utils.bzl", "get_dynamic_library_linking_inputs")


_ClaimedExportsInfo = provider()

def _claimed_exports_aspect_impl(target, ctx):
    return _ClaimedExportsInfo(
        claimed_exports = target[CcSharedLibraryInfo].exports
    )

_claimed_exports_aspect = aspect(
    implementation = _claimed_exports_aspect_impl,
)

def _static_linker_inputs_impl(ctx):
    exports_file = ctx.actions.declare_file(ctx.label.name + "_claimed_exports.txt")
    str_builder = ["Owner:{}".format(ctx.label)]
    str_builder.append("\n".join(ctx.attr.target[0][_ClaimedExportsInfo].claimed_exports))
    ctx.actions.write(content = "\n".join(str_builder), output = exports_file)
    return [
        DefaultInfo(files = depset([exports_file]))
    ]

claimed_exports = rule(
    implementation = _static_linker_inputs_impl,
    attrs = {
        "target": attr.label_list(aspects = [_claimed_exports_aspect])
    },
)
