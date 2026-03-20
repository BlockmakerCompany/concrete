; src/concrete_net.asm - Network Layer (UDP) for Concrete
; Exposes clean functions to create, bind, send, and receive over the network.

%include "concrete.inc"

section .text
    ; Export functions so the linker can see them
    global net_create_udp
    global net_bind_udp
    global net_send_udp
    global net_recv_udp

; -----------------------------------------------------------------------------
; net_create_udp
; Creates a UDP network socket.
; Arguments: None
; Returns: rax = Socket File Descriptor (or negative error code)
; -----------------------------------------------------------------------------
net_create_udp:
    mov rax, SYS_SOCKET    ; syscall 41
    mov rdi, 2             ; AF_INET (IPv4)
    mov rsi, 2             ; SOCK_DGRAM (UDP)
    mov rdx, 0             ; IP Protocol (0)
    syscall
    ret

; -----------------------------------------------------------------------------
; net_bind_udp
; Binds a socket to a local IP and port (required for listening).
; Arguments:
;   rdi = Socket File Descriptor
;   rsi = Pointer to sockaddr_in structure
; Returns: rax = 0 on success, or negative error code
; -----------------------------------------------------------------------------
net_bind_udp:
    mov rax, SYS_BIND      ; syscall 49
    ; rdi already contains the File Descriptor
    ; rsi already contains the pointer to sockaddr_in
    mov rdx, 16            ; Fixed size of sockaddr_in in IPv4
    syscall
    ret

; -----------------------------------------------------------------------------
; net_send_udp
; Sends a UDP packet to a specific destination.
; Arguments:
;   rdi = Socket File Descriptor
;   rsi = Pointer to the data buffer (our SHM)
;   rdx = Size of the data to send
;   rcx = Pointer to the destination sockaddr_in structure
; Returns: rax = bytes sent, or negative error code
; -----------------------------------------------------------------------------
net_send_udp:
    ; sys_sendto expects: fd(rdi), buf(rsi), len(rdx), flags(r10), dest(r8), addrlen(r9)
    mov r8, rcx            ; Move destination sockaddr_in pointer to r8
    mov r9, 16             ; Size of sockaddr_in
    mov r10, 0             ; Flags = 0
    mov rax, SYS_SENDTO    ; syscall 44
    syscall
    ret

; -----------------------------------------------------------------------------
; net_recv_udp
; Reads an incoming UDP packet.
; Arguments:
;   rdi = Socket File Descriptor
;   rsi = Pointer to the destination buffer (our SHM)
;   rdx = Maximum size to read
; Returns: rax = bytes read, or negative error code (-EAGAIN if empty)
; -----------------------------------------------------------------------------
net_recv_udp:
    ; sys_recvfrom expects: fd(rdi), buf(rsi), len(rdx), flags(r10), src(r8), addrlen(r9)
    mov r10, 0             ; Flags = 0
    mov r8, 0              ; src_addr = 0 (We don't care about the source IP for now)
    mov r9, 0              ; addrlen = 0
    mov rax, SYS_RECVFROM  ; syscall 45
    syscall
    ret