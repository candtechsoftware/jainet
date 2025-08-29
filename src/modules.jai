#import "Basic"; 
#import "POSIX";

Network_Result :: enum {
    ERROR;
};

Network_Error :: {
   #as using n: Network_Result; 
   message: string; 
}



Tcp_Listener :: struct {
    fd: int;
} 


set_non_blocking :: (fd: int) -> Network_Result {  
    flags := fcntl(fd, F_GETFL, 0);
    if (flags == -1) return { n: .ERROR, message: "Failed to get network flags"};
    return fcntl(fd, F_SETFL, flags | O_NONBLOCK); 
} 
