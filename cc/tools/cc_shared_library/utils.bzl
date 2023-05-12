def get_dynamic_library(target):
    library = target[CcSharedLibraryInfo].linker_input.libraries[0]
    if library.resolved_symlink_dynamic_library != None:
        return library.resolved_symlink_dynamic_library
    return library.dynamic_library


def get_dynamic_library_linking_inputs(target):
    inputs_set = {}
    for action in target.actions:
        for file in action.outputs.to_list():
            if file.path == get_dynamic_library(target).path:
                for input_file in action.inputs.to_list():
                    inputs_set[input_file.path] = True
    return inputs_set
