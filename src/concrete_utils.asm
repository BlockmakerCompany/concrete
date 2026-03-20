; src/concrete_utils.asm - Utilities and Logging Engine
section .text
    global _print_str
    global _atoi
    global _log_info
    global _log_debug

; External variable defined in concrete_env.asm
extern current_log_level

; -----------------------------------------------------------------------------
; _log_info: Prints only if CONCRETE_LOG >= 1
; -----------------------------------------------------------------------------
_log_info:
    cmp qword [current_log_level], 1
    jl .exit
    call _print_str
.exit:
    ret

; -----------------------------------------------------------------------------
; _log_debug: Prints only if CONCRETE_LOG >= 2
; -----------------------------------------------------------------------------
_log_debug:
    cmp qword [current_log_level], 2
    jl .exit
    call _print_str
.exit:
    ret

; -----------------------------------------------------------------------------
; _print_str: Prints a NULL-terminated string
; -----------------------------------------------------------------------------
_print_str:
    push rax
    push rdi
    push rdx
    push rsi
    mov rdx, 0
.l: cmp byte [rsi+rdx], 0
    je .d
    inc rdx
    jmp .l
.d: mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    syscall
    pop rsi
    pop rdx
    pop rdi
    pop rax
    ret

; -----------------------------------------------------------------------------
; _atoi: String to Integer
; -----------------------------------------------------------------------------
_atoi:
    xor rax, rax
.loop:
    movzx rcx, byte [rsi]
    test rcx, rcx
    jz .done
    cmp rcx, '0'
    jb .done
    cmp rcx, '9'
    ja .done
    sub rcx, '0'
    imul rax, 10
    add rax, rcx
    inc rsi
    jmp .loop
.done:
    ret