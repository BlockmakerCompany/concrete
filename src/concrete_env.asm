; src/concrete_env.asm - Environment Variable Configuration
%include "concrete.inc"

extern _atoi
global init_env
global addr_local, addr_remote, addr_dest
global shm_path_ptr, current_log_level

section .data
    env_port_key db "CONCRETE_PORT", 0
    env_shm_key  db "CONCRETE_SHM", 0
    env_log_key  db "CONCRETE_LOG", 0
    shm_default  db "/dev/shm/concrete.data", 0

section .bss
    ; Network structures (16 bytes each)
    addr_local   resb 16
    addr_remote  resb 16
    addr_dest    resb 16

    shm_path_ptr      resq 1
    current_log_level resq 1 ; 0=Silent, 1=Info, 2=Debug

section .text

init_env:
    ; RBP was preserved in _start and points to argc
    mov r8, [rbp]                   ; r8 = argc
    lea r9, [rbp + 8 + r8*8 + 8]    ; r9 = start of envp (skipping argc and argv)

    ; 1. Search for CONCRETE_LOG
    mov rdi, env_log_key
    call _get_env_internal
    test rax, rax
    jz .default_log
    mov rsi, rax
    call _atoi
    mov [current_log_level], rax
    jmp .setup_shm
.default_log:
    mov qword [current_log_level], 1 ; Default: Info

.setup_shm:
    ; 2. Search for CONCRETE_SHM
    mov rdi, env_shm_key
    call _get_env_internal
    test rax, rax
    jnz .apply_shm
    mov rax, shm_default
.apply_shm:
    mov [shm_path_ptr], rax

    ; 3. Search for CONCRETE_PORT
    mov rdi, env_port_key
    call _get_env_internal
    test rax, rax
    jz .default_port
    mov rsi, rax
    call _atoi
    jmp .apply_port
.default_port:
    mov rax, 8080

.apply_port:
    ; RAX contains the base port (e.g., 8080) in Little Endian format

    ; 1. Configure Remote and Destination ports (Cluster)
    mov rcx, rax                    ; Make a copy of the base port
    xchg cl, ch                     ; Convert to Network Byte Order (Big Endian)

    ; Fill sockaddr_in addr_remote (AF_INET, Port 8080, 0.0.0.0)
    mov word [addr_remote], 2
    mov word [addr_remote + 2], cx
    mov dword [addr_remote + 4], 0x00000000

    ; Fill sockaddr_in addr_dest (AF_INET, Port 8080, 127.0.0.1)
    mov word [addr_dest], 2
    mov word [addr_dest + 2], cx
    mov dword [addr_dest + 4], 0x0100007F

    ; 2. Configure Local port (Base port + 1)
    inc rax                         ; RAX is now 8081
    xchg al, ah                     ; Convert to Network Byte Order (Big Endian)

    ; Fill sockaddr_in addr_local (AF_INET, Port 8081, 127.0.0.1)
    mov word [addr_local], 2
    mov word [addr_local + 2], ax
    mov dword [addr_local + 4], 0x0100007F

    ret

; --- Search for variables in envp ---
_get_env_internal:
    push r9                 ; Save the start of envp
.loop:
    mov rsi, [r9]           ; Load pointer to "KEY=VAL"
    test rsi, rsi           ; End of envp (null)?
    jz .not_found

    push rdi                ; Preserve the searched key
    push rsi
.compare:
    mov al, [rdi]
    mov bl, [rsi]
    test al, al             ; Reached the end of the searched key?
    jz .check_equal
    cmp al, bl
    jne .next_var
    inc rdi
    inc rsi
    jmp .compare
.check_equal:
    cmp byte [rsi], '='     ; Is the next character an '='?
    jne .next_var
    inc rsi                 ; Skip the '='
    mov rax, rsi            ; Return pointer to the value
    pop rsi
    pop rdi
    pop r9
    ret
.next_var:
    pop rsi
    pop rdi
    add r9, 8               ; Next pointer in envp
    jmp .loop
.not_found:
    xor rax, rax
    pop r9
    ret