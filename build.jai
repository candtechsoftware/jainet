process_args :: (opts: *Build_Options, args: []string) {
    index := 0; 
    user_args: [..]string; 

            
    while index < args.count {
        defer index += 1;
        it := args[index];
        if !it continue;

        if it[0] == #char "-" {
            if it == {
                case "-";
                    for i: index+1..args.count-1 array_add(*user_args, args[i]); 
                case "-release"; 
                    set_optimization(opts, .OPTIMIZED);
                    opts.stack_trace = false;
                case "-release_fast"; 
                    array_add(*user_args, args[index]);
                    set_optimization(opts, .VERY_OPTIMIZED);
                    opts.stack_trace = false;
                case "-very_debug";
                    set_optimization(opts, .VERY_DEBUG);
                case "-debugger";
                    opts.interactive_bytecode_debugger = true;
                    set_build_options_dc(.{interactive_bytecode_debugger=true});
                case "-quiet"; 
                    opts.text_output_flags = 0;
                case;
                    log_error("Invalid argument: %\n", args[index]);
                    exit(1);
            } 
        }
    } 
    opts.compile_time_command_line = user_args; 
} 

build :: () {
    set_working_directory(#filepath);
    w := compiler_create_workspace("JaiNet");
    if !w {
        print("Workspace creation failed.\n");
        return;
    }

    opts := get_build_options(w);
    args := opts.compile_time_command_line;
    process_args(*opts, args); 
    modules_paths: [..] string;



    opts.output_executable_name = "jainet";
    opts.output_path = "build/"; 

    make_directory_if_it_does_not_exist(opts.output_path);

    array_add(*modules_paths, "src/modules");
    array_add(*modules_paths, ..opts.import_path);
    opts.import_path = modules_paths;

    set_build_options(opts, w);

    compiler_begin_intercept(w);


    add_build_file("examples/main.jai", w); 

    message_loop();

    compiler_end_intercept(w);
    set_build_options_dc(.{do_output=false});
}

#run build();

message_loop :: () {

    while true {

        message := compiler_wait_for_message();
        print("message kind %\n", message.kind);
        if message.kind == {
          case .FILE;
          case .IMPORT;
          case .PHASE;
          case .TYPECHECKED;
          case .COMPLETE;
            break;
          case;
        }
    }
}

#import "Basic";
#import "Compiler";
#import "File"; 
