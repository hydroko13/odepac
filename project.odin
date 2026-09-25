package main

import "core:strings"
import "core:encoding/json"
import "core:os"

@(private="file")
Odepac_Conf_JsonData :: struct {
    project: string,
    project_type: string
}

Load_Project_Status :: enum {
    Success,
    ConfReadError,
    ConfParseError,
    GetCwdFailure,
    OutOfMem,
}

ProjectType :: enum {
    Application,
    Library,
}

Project :: struct {
    name: string,
    type: ProjectType,
    load_success: bool

}

load_project :: proc() -> (project: Project, status: Load_Project_Status) {

    project.load_success = false

    cwd, err := os.get_working_directory(context.allocator)
    defer delete(cwd)
    if err != os.General_Error.None {
        // ''project'' is left with default values
        status = Load_Project_Status.GetCwdFailure
        return
    }

    conf_path, err2 := os.join_path({cwd, "odepac.json"}, context.allocator)
    defer delete(conf_path) // remember that this MIGHT have to be put after the if statement for memory reasons
    
    if err2 != nil {
        status = Load_Project_Status.OutOfMem
        return
    }


    conf_file_contents, err3 := os.read_entire_file(conf_path, context.allocator)

    if err3 != os.General_Error.None {
        status = Load_Project_Status.ConfReadError
        return
    }

    json_data: Odepac_Conf_JsonData

    parse_err := json.unmarshal(conf_file_contents, &json_data)

    defer delete(json_data.project)
    defer delete(json_data.project_type)

    

    if parse_err != nil {
        status = .ConfParseError
        return
    }

    

    project_name_cloned := strings.clone(json_data.project)
    project.name = project_name_cloned

    if json_data.project_type == "application" {
        project.type = .Application
    }
    else if json_data.project_type == "library" {
        project.type = .Library
    }

    status = .Success
    project.load_success = true

    return

}

unload_project :: proc(project: ^Project) {
    if project.load_success {
        delete(project.name)
    }
}