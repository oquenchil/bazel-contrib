load(":utils.bzl", "get_dynamic_library", "get_dynamic_library_linking_inputs")

def _create_objects_to_target_str(objects, target, inputs_set):
    object_file_to_target = []
    for object_file in objects:
        if object_file.path in inputs_set:
            object_file_to_target.append(object_file.path + "*" + target)
    return object_file_to_target

ExportsFinderInfo=provider()

def _exports_finder_aspect_impl(target, ctx):
    inputs_set = get_dynamic_library_linking_inputs(target)

    deps_cc_infos = []
    for dep in ctx.rule.attr.deps:
        deps_cc_infos.append(dep[CcInfo])

    merged_cc_info = cc_common.merge_cc_infos(cc_infos = deps_cc_infos)

    object_file_to_target = []
    object_inputs = []
    for linker_input in merged_cc_info.linking_context.linker_inputs.to_list():
        for library in linker_input.libraries:
            object_inputs.extend(library.objects)
            object_file_to_target.extend(_create_objects_to_target_str(library.objects, str(linker_input.owner), inputs_set))
            object_inputs.extend(library.pic_objects)
            object_file_to_target.extend(_create_objects_to_target_str(library.pic_objects, str(linker_input.owner), inputs_set))

    object_file_to_target_map_file = ctx.actions.declare_file(ctx.label.name + "_object_file_to_target_map.txt")
    ctx.actions.write(content = "\n".join(object_file_to_target), output = object_file_to_target_map_file)


    so_file = get_dynamic_library(target)
    targets_of_exported_objects_file = ctx.actions.declare_file(ctx.label.name + "_targets_of_exported_objects.txt")
    ctx.actions.run_shell(
        inputs = [so_file, object_file_to_target_map_file] + object_inputs,
        outputs = [targets_of_exported_objects_file],
        progress_message = "Finding exported targets for {}".format(so_file.short_path),
        command = """
            function extract_global_symbols_object() {{
              echo "$1" | cut -f2,5 -d" " | grep ^g | cut -f2 -d" "
            }}

            output_file={targets_of_exported_objects_file_path}
            declare -A file_to_target_dict
            while read line; do
              object_file=$(echo $line | cut -d "*" -f1)
              target=$(echo $line | cut -d "*" -f2)
              file_to_target_dict["$object_file"]="$target"
            done < {object_file_to_target_map_path}

            object_files_objdump_output=$(objdump -t "${{!file_to_target_dict[@]}}" | tr -s " ")

            IFS=$'\n'

            declare -A object_file_to_table

            filename=""
            curr_file_symbol_table=""

            for line in `echo "$object_files_objdump_output"`
            do
              if [[ "$line" == *"file format"* ]]; then
                if [ ! -z "$curr_file_symbol_table" ]
                then
                  object_file_to_table["$filename"]=$(extract_global_symbols_object "$curr_file_symbol_table")
                  curr_file_symbol_table=""
                fi
                filename=$(echo "$line" | cut -f1 -d:)
              else
                curr_file_symbol_table="${{curr_file_symbol_table}}${{IFS}}${{line}}"
              fi
            done
            object_file_to_table["$filename"]=$(extract_global_symbols_object "$curr_file_symbol_table")

            declare -A symbol_to_file
            for key in "${{!object_file_to_table[@]}}"; do
              value="${{object_file_to_table[$key]}}"
              value_list=($value)
              for element in ${{value_list[@]}}; do
                symbol_to_file["$element"]="$key"
              done
            done


            shared_object_objdump_output=$(objdump -T {so_file_path} | tr -s " ")
            shared_object_global_symbols=($(echo "$shared_object_objdump_output" | cut -f2,6 -d" " | grep ^g | cut -f2 -d" "))

            declare -A target_to_demangled_symbols
            for symbol in "${{shared_object_global_symbols[@]}}"; do
              if [[ "${{symbol_to_file[$symbol]}}" ]]; then
                object_file=${{symbol_to_file[${{symbol}}]}}
                target=${{file_to_target_dict[$object_file]}}
                demangled_symbol=$(c++filt $symbol)
                target_to_demangled_symbols[$target]="${{demangled_symbol}}","${{target_to_demangled_symbols[$target]}}"
              fi
            done

            echo "Targets exported by {so_file_path}" > "$output_file"
            for target in "${{!target_to_demangled_symbols[@]}}"; do
              demangled_symbols=$(echo "${{target_to_demangled_symbols[$target]}}" | tr "," "\\n")
              echo "Symbols for ${{target}}:" >> "$output_file"
              echo -e "\\t$demangled_symbols" >> "$output_file"
            done

        """.format(
            so_file_path = so_file.path,
            object_file_to_target_map_path = object_file_to_target_map_file.path,
            targets_of_exported_objects_file_path =  targets_of_exported_objects_file.path
        ),
    )


    return [ExportsFinderInfo(file=targets_of_exported_objects_file)]


exports_finder_aspect = aspect(
    implementation = _exports_finder_aspect_impl,
    doc = """
    Currently, only works for object files being linked into the shared object. This could be expanded to support archives as well.
    """
)

def _exports_finder_impl(ctx):

    return [
        DefaultInfo(files = depset([ctx.attr.target[0][ExportsFinderInfo].file]))
    ]


exports_finder = rule(
    implementation = _exports_finder_impl,
    attrs = {
        "target": attr.label_list(aspects = [exports_finder_aspect])
    },
)
