; src/concrete_signals.asm - Graceful Shutdown Handler
%include "concrete.inc"

extern _log_info
global init_signals

section .data
    msg_shutdown db "Concrete: SIGTERM received. Shutting down gracefully...", 10, 0

section .bss
    ; sigaction structure (32 bytes in x86_64)
    ; void (*sa_handler)(int); (8 bytes)
    ; unsigned long sa_flags;  (8 bytes)
    ; void (*sa_restorer)(void); (8 bytes)
    ; sigset_t sa_mask;        (8 bytes)
    act resb 32

section .text

; -----------------------------------------------------------------------------
; init_signals: Registers the handler for SIGTERM (15) and SIGINT (2)
; -----------------------------------------------------------------------------
init_signals:
    ; Prepare sigaction structure
    mov qword [act], sig_handler      ; sa_handler points to our function
    mov qword [act + 8], 0            ; sa_flags = 0
    mov qword [act + 16], 0           ; sa_restorer = NULL
    mov qword [act + 24], 0           ; sa_mask = 0 (no additional mask)

    ; Register SIGTERM (15)
    mov rax, 13                       ; SYS_RT_SIGACTION
    mov rdi, 15                       ; SIGTERM
    mov rsi, act                      ; New action
    xor rdx, rdx                      ; Previous action (NULL)
    mov r10, 8                        ; Size of sigset_t (8 bytes)
    syscall

    ; Register SIGINT (2)
    mov rax, 13                       ; SYS_RT_SIGACTION
    mov rdi, 2                        ; SIGINT
    mov rsi, act
    xor rdx, rdx
    mov r10, 8
    syscall

    ret

; -----------------------------------------------------------------------------
; sig_handler: Executed when the signal arrives
; -----------------------------------------------------------------------------
sig_handler:
    ; Print farewell message
    mov rsi, msg_shutdown
    call _log_info

    ; We could close the FDs here, but Linux closes them automatically
    ; on exit. We exit with code 0 (Success).
    mov rax, 60                       ; SYS_EXIT
    xor rdi, rdi                      ; Exit code 0
    syscall