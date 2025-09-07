Loop_Handle :: s32; 


Loop_Entry :: struct {
    fd:        int; 
    type:      Loop_Event_Type;
    cb:        Loop_CB;
    user_data: *void; 
} 

Loop :: struct {
    allocator:    Allocator; 
    handle:       Loop_Handle;
    running:      bool;
    entries:      []Loop_Entry; 
    entry_count:  u32; 
} 

kq_ev_set :: inline (k: *Kevent64, ident: u64, filter: Kevent_Filter, flags: Kevent_Flags, fflags: Kevent_Fflags, data: s64, user_data: *void) {
    k.ident  = ident;
    k.filter = filter; 
    k.flags  = flags; 
    k.fflags = fflags; 
    k.data   = data; 
    k.udata  = user_data; 
} 


loop_create :: (alloc: Allocator) -> *Loop {
    push_allocator(alloc);
    loop := New(Loop);
    loop.allocator = alloc;
    loop.handle = xx kqueue();
    loop.entries = NewArray(1024, Loop_Entry);
    return loop; 
} 

loop_destroy :: (loop: *Loop) {
    free(loop,, loop.allocator); 
    return; 
} 


loop_register_event :: (loop: *Loop, handle: Loop_Handle, type: Loop_Event_Type) {
    kv: Kevent64; 
    if type & .READ {
        kq_ev_set(*kv, cast(u64)handle, .READ, .ADD | .ENABLE, 0, 0, null);
        kevent64(loop.handle, *kv, 1, null, 0, .KEVENT_FLAG_NONE, null);
    } 
    if type & .WRITE {
        kq_ev_set(*kv, cast(u64)handle, .WRITE, .ADD | .ENABLE, 0, 0, null);
        kevent64(loop.handle, *kv, 1, null, 0, .KEVENT_FLAG_NONE, null);
    } 
} 


loop_add :: (loop: *Loop, handle: Loop_Handle, type: Loop_Event_Type, cb: Loop_CB, user_data: *void) -> bool {
    if (handle >= loop.entries.count) return false;
    loop.entries[handle].fd = handle; 
    loop.entries[handle].cb = cb;
    loop.entries[handle].type = type; 
    loop.entries[handle].user_data = user_data; 
    loop_register_event(loop, handle, type); 
    return true; 
}

loop_remove :: (loop: *Loop, handle: Loop_Handle) -> bool {
    if handle >= loop.entries.count return false;
    
    entry := loop.entries[handle];
    kv: Kevent64; 
    
    if entry.type & .READ {
        kq_ev_set(*kv, cast(u64)handle, .READ, .DELETE, 0, 0, null);
        kevent64(loop.handle, *kv, 1, null, 0, .KEVENT_FLAG_NONE, null);
    } 

    if entry.type & .WRITE {
        kq_ev_set(*kv, cast(u64)handle, .WRITE, .DELETE, 0, 0, null);
        kevent64(loop.handle, *kv, 1, null, 0, .KEVENT_FLAG_NONE, null);
    } 
    memset(*loop.entries[handle], 0, size_of(Loop_Entry));
    return true;
} 


loop_run :: (loop: *Loop) {
    loop.running = true; 
    k_list: [64]Kevent64;
    while loop.running {
        n := kevent64(loop.handle, null, 0, k_list.data, 64, .KEVENT_FLAG_NONE, null);
        if n < 0 {
            log_error("kevent64 error: %", errno());
            continue;
        }
        
        for i: 0..n-1 {
            handle := cast(Loop_Handle)k_list[i].ident;
            if handle < loop.entries.count {
                entry := *loop.entries[handle];
                if entry.cb then entry.cb(handle, entry.user_data); 
            }
        } 
    } 
} 

loop_stop :: inline (loop: *Loop) {
    loop.running = false;
}


 


#import "POSIX";
#import "macos";
