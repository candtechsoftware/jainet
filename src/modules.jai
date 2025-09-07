Request_Context :: struct {
    server:    *Server;
    socket:    Socket;
    pool:      Flat_Pool;
    allocator: Allocator;
    request:   HTTP_Request;
    response:  HTTP_Response;
}

Server :: struct {
    allocator: Allocator;
    handle: Socket;
    config: Server_Config; 
    loop:   *Loop;
} 


Server_Config :: struct {
    port: u16;
    host: string; 
} 


server_create :: (alloc: Allocator, config: Server_Config) -> Server, bool {
    s: Server; 
    
    // Initialize socket library (needed on Windows)
    if !socket_init() {
        log_error("Failed to initialize socket library");
        return s, false;
    }
    
    s.handle = socket(AF_INET, .STREAM, 0);
    if s.handle == INVALID_SOCKET {
        log_error("Error creating socket");
        return s, false; 
    } 
    
    // Set socket options
    set_keepalive(s.handle, true, 60, 10, 5);
    
    // Enable SO_REUSEADDR to avoid TIME_WAIT issues
    option_value: s32 = 1;
    setsockopt(s.handle, SOL_SOCKET, SO_REUSEADDR, xx *option_value, size_of(type_of(option_value)));
    
    // Bind to address and port
    res := bind(s.handle, config.host, config.port); 
    if res == SOCKET_ERROR {
        log_error("Error binding to socket: %", get_last_socket_error());
        close_and_reset(*s.handle);
        return s, false; 
    } 

    s.allocator = alloc; 
    s.loop      = loop_create(alloc); 
    s.config    = config; 
    return s, true; 
} 

server_destroy :: (s: *Server) {
    if s.loop {
        loop_stop(s.loop);
        loop_destroy(s.loop);
    }
    close_and_reset(*s.handle);
} 

server_listen :: (s: *Server) {
    res := listen(s.handle, 128);
    if res == SOCKET_ERROR {
        log_error("Error listening on socket: %", get_last_socket_error());
        return;
    }
    
    // Set non-blocking mode
    set_blocking(s.handle, false);
    
    // Register with event loop for read events (incoming connections)
    loop_add(s.loop, cast(Loop_Handle)s.handle, .READ, server_accept_callback, s);
    
    log("Server listening on %:%", s.config.host, s.config.port);
    
    // Run the event loop
    loop_run(s.loop);
}

server_accept_callback :: (handle: Loop_Handle, user_data: *void) {
    server := cast(*Server)user_data;
    
    client_socket, client_addr := accept(server.handle);
    if client_socket == INVALID_SOCKET {
        err := get_last_socket_error();
        if err != SOCKET_WOULDBLOCK {
            log_error("Error accepting connection: %", err);
        }
        return;
    }
    
    // Set client socket to non-blocking
    set_blocking(client_socket, false);
    
    log("Accepted connection from %", to_string(client_addr));
    
    // Create context with its own pool allocator
    ctx: Request_Context;
    ctx.server = server;
    ctx.socket = client_socket;
    ctx.allocator = Allocator.{flat_pool_allocator_proc, *ctx.pool};
    
    // Set context allocator as current
    push_allocator(ctx.allocator);
    defer {
        // Clean up the pool when done
        reset(*ctx.pool);
        close_and_reset(*client_socket);
    }
    
    // Read the request - may need multiple attempts for non-blocking socket
    buffer: [4096]u8;
    total_read := 0;
    max_attempts := 10;
    
    for attempt: 0..max_attempts-1 {
        bytes_read := recv(client_socket, buffer.data + total_read, cast(u64)(buffer.count - total_read), 0);
        
        if bytes_read > 0 {
            total_read += bytes_read;
            // Check if we have a complete HTTP request (ends with \r\n\r\n)
            request_str := to_string(buffer.data, total_read);
            if find_index_from_left(request_str, "\r\n\r\n") != -1 {
                break; // We have complete headers
            }
        } else if bytes_read == 0 {
            log("Client closed connection");
            return;
        } else {
            err := get_last_socket_error();
            if err == 35 || err == SOCKET_WOULDBLOCK { // EAGAIN/EWOULDBLOCK
                // No data available yet, wait a bit
                usleep(1000); // Wait 1ms
                continue;
            } else {
                log_error("Failed to read request: %", err);
                return;
            }
        }
    }
    
    if total_read > 0 {
        request_str := to_string(buffer.data, total_read);
        
        // Parse the HTTP request
        parse_err: Parse_Error;
        ctx.request, parse_err = parse_request(request_str, ctx.allocator);
        
        if parse_err != .NONE {
            log_error("Failed to parse request: %", parse_err);
            return;
        }
        
        // Log the parsed request
        print("\n========================================\n");
        print("REQUEST:\n");
        print("  Method: %\n", ctx.request.method);
        print("  Path: %\n", ctx.request.path);
        print("  Version: %\n", ctx.request.version);
        print("  Headers:\n");
        for ctx.request.headers {
            print("    %: %\n", it.name, it.value);
        }
        if ctx.request.body.count > 0 {
            print("  Body: %\n", ctx.request.body);
        }
        
        // Build and send response
        ctx.response = response_init(ctx.allocator);
        
        response_set_status(*ctx.response, 200, "OK");
        response_add_header(*ctx.response, "Content-Type", "text/plain");
        response_add_header(*ctx.response, "Connection", "close");
        response_set_body(*ctx.response, "GOT IT\n");
        
        response_str := response_build(*ctx.response);
        
        print("\nRESPONSE:\n%", response_str);
        print("========================================\n");
        
        bytes_sent := send(client_socket, response_str.data, cast(u64)response_str.count, 0);
        if bytes_sent < 0 {
            log_error("Failed to send response: %", get_last_socket_error());
        } else {
            log("Sent % bytes", bytes_sent);
        }
    }
} 



#load "event_loop/module.jai";
#load "http.jai";
#import "Socket";
#import "Flat_Pool";
#import "POSIX"; 
