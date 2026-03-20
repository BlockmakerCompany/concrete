; src/concrete_main.asm - Orchestrator and State Owner
%include "concrete.inc"

; --- EXPORTS (Main owns these, Sync uses them) ---
global shm_ptr, fd_local, fd_remote, fd_epoll
global ep_event, ep_events, rx_buffer, tx_buffer
global msg_start, msg_local, msg_remote

; --- IMPORTS ---
extern init_env, shm_init
extern init_signals                ; <--- [NEW] Import the signal handler
extern net_create_udp, net_bind_udp
extern _log_info, _log_debug
extern sync_handle_local, sync_handle_remote

; Imported from concrete_env.asm
extern addr_local, addr_remote, shm_path_ptr

section .data
    msg_start   db "Concrete: Dynamic Epoll Core Started.", 10, 0
    msg_local   db "Concrete: LOCAL Event -> Delta sent to Cluster.", 10, 0
    msg_remote  db "Concrete: REMOTE Event -> Merge applied to RAM.", 10, 0

section .bss
    ; Real buffers and file descriptors live here
    shm_ptr     resq 1
    fd_local    resq 1
    fd_remote   resq 1
    fd_epoll    resq 1
    ep_event    resb 16
    ep_events   resb 16
    rx_buffer   resb 1024
    tx_buffer   resb 80    ; 80 bytes to support the Magic Header

section .text
    global _start

_start:
    ; 1. PREPARATION AND INITIALIZATION
    mov rbp, rsp            ; Save stack pointer for init_env
    call init_env           ; Processes CONCRETE_PORT, SHM, and LOG

    ; --- [UPDATED] Activate Graceful Shutdown ---
    call init_signals

    ; 2. RESOURCES: Shared Memory
    mov rdi, [shm_path_ptr]
    mov rsi, SHM_SIZE
    call shm_init
    mov [shm_ptr], rax

    ; 3. RESOURCES: Network (Sockets)
    call net_create_udp
    mov [fd_local], rax
    mov rdi, rax
    mov rsi, addr_local
    call net_bind_udp

    call net_create_udp
    mov [fd_remote], rax
    mov rdi, rax
    mov rsi, addr_remote
    call net_bind_udp

    ; 4. MULTIPLEXER SETUP (Epoll)
    mov rax, SYS_EPOLL_CREATE1
    xor rdi, rdi
    syscall
    mov [fd_epoll], rax

    ; Add Local Socket (ID 1)
    mov dword [ep_event], EPOLLIN
    mov qword [ep_event + 4], 1
    mov rax, SYS_EPOLL_CTL
    mov rdi, [fd_epoll]
    mov rsi, EPOLL_CTL_ADD
    mov rdx, [fd_local]
    mov r10, ep_event
    syscall

    ; Add Remote Socket (ID 2)
    mov dword [ep_event], EPOLLIN
    mov qword [ep_event + 4], 2
    mov rax, SYS_EPOLL_CTL
    mov rdi, [fd_epoll]
    mov rsi, EPOLL_CTL_ADD
    mov rdx, [fd_remote]
    mov r10, ep_event
    syscall

    ; 5. STARTUP LOG
    mov rsi, msg_start
    call _log_info

    ; 6. INFINITE EVENT LOOP
.epoll_loop:
    mov rax, SYS_EPOLL_WAIT
    mov rdi, [fd_epoll]
    mov rsi, ep_events
    mov rdx, 1
    mov r10, -1
    syscall

    test rax, rax
    js .epoll_loop

    ; Dispatcher based on event ID
    mov rcx, [ep_events + 4]
    cmp rcx, 1
    je .call_local
    cmp rcx, 2
    je .call_remote
    jmp .epoll_loop

.call_local:
    call sync_handle_local
    jmp .epoll_loop

.call_remote:
    call sync_handle_remote
    jmp .epoll_loop