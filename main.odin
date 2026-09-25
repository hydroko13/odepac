package main

import "core:fmt"
import "core:io"
import "core:os"
import "core:strings"


Odepac_Command :: enum {
	Run,
	Release,
	Debug,
}


run_project_command :: proc() {
	project, load_status := load_project()
	defer unload_project(&project)
	if load_status != .Success {

		fmt.printfln("Command failed with error: %s", load_status)

		return
	}
	fmt.printfln("Loaded project: %s", project.name)

	cwd, err := os.get_working_directory(context.allocator)
	defer delete(cwd)

	if err != os.General_Error.None {

		fmt.printfln("Command failed with error: %s", err)

		return
	}

	src_path, err2 := os.join_path({cwd, "src"}, context.allocator)
	defer delete(src_path)

	if err2 != nil {
		fmt.printfln("Command failed with error: %s", err2)

		return
	}

	temp_directory, mkdir_err := os.make_directory_temp(cwd, "t", context.allocator)

	if mkdir_err != os.General_Error.None {
		return
	}


	fmt.printfln("Using temp dir %s ", temp_directory)

	joined_path, jerr := os.join_path({temp_directory, project.name}, context.allocator)

	if jerr != nil {
		fmt.printfln("Command failed with error: %s", jerr)

		return
	}

	mkdir_err2 := os.make_directory(joined_path)
	if mkdir_err2 != os.General_Error.None {

		fmt.printfln("Command failed with error: %s", mkdir_err2)

		return
	}

	copy_err := os.copy_directory_all(joined_path, src_path)


	if copy_err != os.General_Error.None {
		fmt.printfln("Command failed with error: %s", copy_err)

		return
	}

	compile_errs_pipe_read, compile_errs_pipe_write, pipe_err := os.pipe()

	if pipe_err != os.General_Error.None {
		fmt.printfln("Command failed with error: %s", pipe_err)
		return
	}

	defer os.close(compile_errs_pipe_read)

	build_process_desc := os.Process_Desc {
		working_dir = joined_path,
		command     = {"odin", "build", "-out:project.exe", "."},
		stdout      = os.stdout,
		stderr      = compile_errs_pipe_write,
	}

	fmt.println("Compiling...")

	p, perr := os.process_start(build_process_desc)
	if perr != os.General_Error.None {
		fmt.printfln("Command failed with error: %s", perr)
		return
	}

	pstate, wait_err := os.process_wait(p)
	if wait_err != os.General_Error.None {
		fmt.printfln("Command failed with error: %s", wait_err)
		return
    }

    fmt.printfln("Odin build command finished with exit code %d", pstate.exit_code)

	os.close(compile_errs_pipe_write)

	pipe_as_stream := os.to_stream(compile_errs_pipe_read)

	compile_errs_buf := make([dynamic]byte)

    immediate_eof: bool
    just_started_reading := true

    for {
        b, read_err := io.read_byte(pipe_as_stream)
        if read_err == .EOF {
            if just_started_reading {
                immediate_eof = true
            } else {
                immediate_eof = false
            }
            break
        } else if read_err != nil {
            fmt.printfln("Command failed with error: %s", read_err)
            return
        }

        append(&compile_errs_buf, b)
        just_started_reading = false
    }



    if immediate_eof {
        fmt.println("Compiled without errors!")
    } else {
        fmt.println("ERRORS: ")
        fmt.println(string(compile_errs_buf[:]))

        remove_err := os.remove_all(temp_directory)
        if remove_err != os.General_Error.None {
            fmt.printfln("Remove temp dir failed with error: %s", remove_err)

            
        }
        
        return

    }




	temp_directory2, mkdir_err3 := os.make_directory_temp(cwd, "t", context.allocator)

	if mkdir_err3 != os.General_Error.None {

		fmt.printfln("Command failed with error: %s", mkdir_err3)

		return
	}


	exec_path, jerr2 := os.join_path(
		{temp_directory, project.name, "project.exe"},
		context.allocator,
	)

	if jerr2 != nil {
		fmt.printfln("Command failed with error: %s", jerr2)

		return
	}


	when ODIN_OS == .Windows {
		out_exec_name, concaterr := strings.concatenate({project.name, ".exe"})
		if concaterr != nil {
			fmt.printfln("Command failed with error: %s", concaterr)

			return
		}

	} else when ODIN_OS == .Linux {
		out_exec_name := project.name
	}


	out_exec_path, jerr3 := os.join_path({temp_directory2, out_exec_name}, context.allocator)

	if jerr3 != nil {
		fmt.printfln("Command failed with error: %s", jerr3)

		return
	}

	copy_err2 := os.copy_file(out_exec_path, exec_path)
	if copy_err2 != os.General_Error.None {
		fmt.printfln("Command failed with error: %s", copy_err2)

		return
	}

	remove_err := os.remove_all(temp_directory)
	if remove_err != os.General_Error.None {
		fmt.printfln("Command failed with error: %s", remove_err)

		return
	}

	run_process_desc := os.Process_Desc {
		working_dir = temp_directory2,
		command     = {out_exec_path},
		stdout      = os.stdout,
		stderr      = os.stderr,
	}

	fmt.println("###### PROGRAM START ######")

	run_p, perr2 := os.process_start(run_process_desc)
	if perr2 != os.General_Error.None {
		fmt.printfln("Command failed with error: %s", perr2)
		return
	}

	pstate2, wait_err2 := os.process_wait(run_p)
	if wait_err2 != os.General_Error.None {
		fmt.printfln("Command failed with error: %s", wait_err2)
		return
	}

    remove_err2 := os.remove_all(temp_directory2)
    if remove_err2 != os.General_Error.None {
        fmt.printfln("Remove temp dir failed with error: %s", remove_err2)

        
    }

}

build_project_command :: proc() {

}

main :: proc() {
	fmt.println("Odepac v0.1")

	command: Odepac_Command
	args_count := len(os.args[1:])
	if args_count == 0 {
		command = .Run
	} else if args_count == 1 {
		if os.args[1:][0] == "run" {
			command = .Run
		} else if os.args[1:][0] == "release" {
			command = .Release
		} else if os.args[1:][0] == "debug" {
			command = .Debug
		}
	}

	if command == .Run {
		fmt.println("Running project...")
		run_project_command()
	} else if command == .Release {
		fmt.println("Building project... mode - Release")
	} else if command == .Debug {
		fmt.println("Building project... mode - Debug")
	}


}
