#import "Basic";
#import "Flat_Pool"; 
#import,file "../src/modules.jai";


main :: () {
    pool: Flat_Pool; 
    alloc := Allocator.{flat_pool_allocator_proc, *pool}; 

    server, ok := server_create(alloc, .{ port = 8080, host = "127.0.0.1" });
    if !ok {
        return; 
    } 
    defer server_destroy(*server); 

    server_listen(*server); 
}

