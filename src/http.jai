HTTP_Method :: enum {
    GET;
    POST;
    PUT;
    DELETE;
    HEAD;
    OPTIONS;
    PATCH;
    CONNECT;
    TRACE;
}

HTTP_Version :: enum {
    HTTP_1_0;
    HTTP_1_1;
    HTTP_2_0;
}

HTTP_Header :: struct {
    name:  string;
    value: string;
}

HTTP_Request :: struct {
    method:         HTTP_Method;
    path:           string;
    version:        HTTP_Version;
    headers:        [..]HTTP_Header;
    body:           string;
    content_length: s64;
    allocator:      Allocator;
}

HTTP_Response :: struct {
    status_code:    u16;
    status_text:    string;
    version:        HTTP_Version;
    headers:        [..]HTTP_Header;
    body:           string;
    allocator:      Allocator;
}

Parse_Error :: enum {
    NONE;
    INVALID_METHOD;
    INVALID_VERSION;
    MALFORMED_REQUEST;
    INCOMPLETE_REQUEST;
}

parse_request :: (data: string, allocator: Allocator) -> HTTP_Request, Parse_Error {
    request: HTTP_Request;
    request.allocator = allocator;
    array_reserve(*request.headers, 16);
    
    lines := split(data, "\r\n",, allocator);
    if lines.count == 0 return request, .MALFORMED_REQUEST;
    
    // Parse request line
    parts := split(lines[0], " ",, allocator);
    if parts.count != 3 return request, .MALFORMED_REQUEST;
    
    // Parse method
    method_str := parts[0];
    if method_str == {
        case "GET";     request.method = .GET;
        case "POST";    request.method = .POST;
        case "PUT";     request.method = .PUT;
        case "DELETE";  request.method = .DELETE;
        case "HEAD";    request.method = .HEAD;
        case "OPTIONS"; request.method = .OPTIONS;
        case "PATCH";   request.method = .PATCH;
        case "CONNECT"; request.method = .CONNECT;
        case "TRACE";   request.method = .TRACE;
        case; return request, .INVALID_METHOD;
    }
    
    // Parse path
    request.path = copy_string(parts[1],, allocator);
    
    // Parse version
    version_str := parts[2];
    if version_str == {
        case "HTTP/1.0"; request.version = .HTTP_1_0;
        case "HTTP/1.1"; request.version = .HTTP_1_1;
        case "HTTP/2.0"; request.version = .HTTP_2_0;
        case; return request, .INVALID_VERSION;
    }
    
    // Parse headers
    header_end := 0;
    for i: 1..lines.count-1 {
        if lines[i].count == 0 {
            header_end = i;
            break;
        }
        
        colon_pos := find_index_from_left(lines[i], ":");
        if colon_pos == -1 continue;
        
        header: HTTP_Header;
        header.name = trim(slice(lines[i], 0, colon_pos), " \t",, allocator);
        header.value = trim(slice(lines[i], colon_pos + 1, lines[i].count - colon_pos - 1), " \t",, allocator);
        
        array_add(*request.headers, header);
        
        // Check for Content-Length
        if equal_nocase(header.name, "Content-Length") {
            request.content_length = string_to_int(header.value);
        }
    }
    
    // Parse body if present
    if header_end > 0 && header_end < lines.count - 1 {
        body_lines: [..]string;
        body_lines.allocator = allocator;
        for i: header_end + 1..lines.count - 1 {
            array_add(*body_lines, lines[i]);
        }
        request.body = join(..body_lines, "\r\n",, allocator);
    }
    
    return request, .NONE;
}

response_init :: (allocator: Allocator) -> HTTP_Response {
    response: HTTP_Response;
    response.allocator = allocator;
    response.version = .HTTP_1_1;
    response.status_code = 200;
    response.status_text = "OK";
    array_reserve(*response.headers, 8);
    return response;
}

response_set_status :: (response: *HTTP_Response, code: u16, text: string) {
    response.status_code = code;
    response.status_text = copy_string(text,, response.allocator);
}

response_add_header :: (response: *HTTP_Response, name: string, value: string) {
    header: HTTP_Header;
    header.name = copy_string(name,, response.allocator);
    header.value = copy_string(value,, response.allocator);
    array_add(*response.headers, header);
}

response_set_body :: (response: *HTTP_Response, body: string) {
    response.body = copy_string(body,, response.allocator);
    response_add_header(response, "Content-Length", tprint("%", body.count));
}

response_build :: (response: *HTTP_Response) -> string {
    builder: String_Builder;
    builder.allocator = response.allocator;
    
    // Status line
    version_str := "HTTP/1.1";
    if response.version == .HTTP_1_0 version_str = "HTTP/1.0";
    else if response.version == .HTTP_2_0 version_str = "HTTP/2.0";
    
    append(*builder, tprint("% % %\r\n", version_str, response.status_code, response.status_text));
    
    // Headers
    for response.headers {
        append(*builder, tprint("%: %\r\n", it.name, it.value));
    }
    
    // Empty line before body
    append(*builder, "\r\n");
    
    // Body
    if response.body.count > 0 {
        append(*builder, response.body);
    }
    
    return builder_to_string(*builder,, response.allocator);
}

#import "Basic";
#import "String";