#import "Basic"; 
#if OS == {
    case .LINUX; #load "io_uring.jai";
    case .MACOS;  #load "kqueue.jai";
    case; assert(false, "Windows not implemented");
}


Loop_CB :: #type (handle: Loop_Handle, user_data: *void); 


Loop_Event_Type :: enum_flags {
    READ  :: 0x1;
    WRITE :: 0x2;
} 
