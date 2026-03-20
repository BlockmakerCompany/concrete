; src/concrete.inc - Concrete Global Definitions

; --- x86_64 Syscalls ---
%define SYS_READ        0
%define SYS_WRITE       1
%define SYS_OPEN        2
%define SYS_CLOSE       3
%define SYS_MMAP        9
%define SYS_SOCKET      41
%define SYS_SENDTO      44
%define SYS_RECVFROM    45
%define SYS_BIND        49
%define SYS_EXIT        60
%define SYS_FTRUNCATE   77
%define SYS_EPOLL_WAIT  232
%define SYS_EPOLL_CTL   233
%define SYS_EPOLL_CREATE1 291

; --- Concrete Constants ---
%define SHM_SIZE        4096
%define PORT_SYNC       8080    ; Port for communicating with other nodes (Cluster)
%define PORT_LOCAL      8081    ; Port for the App to wake up the Agent

; --- Epoll Constants ---
%define EPOLL_CTL_ADD   1
%define EPOLLIN         1       ; Bit 0: Data available to read

; --- Shared Memory Offsets ---
%define OFFSET_SEM      0       ; 4 bytes
%define OFFSET_DIRTY    8       ; 8 bytes (64 bits for 64 blocks)
%define BLOCK_SIZE      64      ; Each block is 64 bytes long