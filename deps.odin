package main

import "core:fmt"
import "core:os"

prepare_dependencies :: proc(project: ^Project, code_temp_directory: string, libs_path: string) -> (deps_path: string, ok: bool) {
    temp_lib_collection_path, err1  := os.join_path({code_temp_directory, "odepac_deps"}, context.allocator)
    
    if err1 != nil {
        fmt.printfln("Join path failed when preparing dependecy directories: %s", err1)
        return temp_lib_collection_path, false
    }
    mkdir_err := os.make_directory(temp_lib_collection_path)
    if mkdir_err != os.General_Error.None {
        fmt.printfln("Make directory failed when preparing dependecy directories: %s", mkdir_err)
        return temp_lib_collection_path, false
    }



    for dependency in project.deps {
        dependency_path, err2 := os.join_path({libs_path, dependency, "src"}, context.allocator)
        defer delete(dependency_path)
        if err2 != nil {
            fmt.printfln("A/ Join path failed when preparing dependency: %s (%s)", dependency, err2)
            return temp_lib_collection_path, false
        }
        temp_dependency_path, err3 := os.join_path({temp_lib_collection_path, dependency}, context.allocator)
        defer delete(temp_dependency_path)
        if err3 != nil {
            fmt.printfln("B/ Join path failed when preparing dependency: %s (%s)", dependency, err3)
            return temp_lib_collection_path, false
        }
        fmt.println(dependency_path)
        fmt.println(libs_path)
        copy_err := os.copy_directory_all(temp_dependency_path, dependency_path)
        if copy_err != os.General_Error.None {
            fmt.printfln("Copy directory failed when preparing dep: %s (%s)", dependency, copy_err)
            return temp_lib_collection_path, false
        }
    }
    
    return temp_lib_collection_path, true
}
