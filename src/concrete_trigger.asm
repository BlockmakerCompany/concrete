; src/concrete_trigger.asm - Utility to trigger synchronization (Secure)
%include "concrete.inc"

extern net_create_udp
extern net_send_udp
extern _atoi            ; We use the _atoi that already lives in utils

; Export this so concrete_utils.o doesn't complain during compilation
global current_log_level
global _start

section .data
    addr_core:
        dw 2            ; AF_INET
        dw 0x901F       ; Port 8080 (Big Endian)
        dd 0x0100007F   ; 127.0.0.1
        dq 0

    current_log_level dq 2          ; Fake a log level for utils
    magic_header      db "CONCRETE" ; The Agent's master key

section .bss
    tx_buffer   resb 80             ; Increased to 80 bytes [Magic:8 | ID:8 | Payload:64]
    fd_sock     resq 1

section .text

_start:
    pop rax             ; argc
    cmp rax, 3
    jl .exit_error

    pop rax             ; Skip program name (argv[0])

    ; --- 1. Read and process ID (argv[1]) ---
    pop rsi             ; rsi = string ID
    call _atoi          ; rax = numeric ID

    ; --- 2. Assemble Secure Packet ---
    ; Write Magic Header at offset 0
    mov rcx, [magic_header]
    mov [tx_buffer], rcx

    ; Write Block ID at offset 8
    mov [tx_buffer + 8], rax

    ; --- 3. Copy Payload at offset 16 ---
    pop rsi             ; rsi = pointer to MESSAGE (argv[2])
    mov rdi, tx_buffer + 16
    mov rcx, 64
.copy_msg:
    lodsb
    stosb
    test al, al         ; Reached the end of the string (NULL)?
    jz .fill_zeros
    loop .copy_msg
    jmp .send

.fill_zeros:
    ; Fill the rest of the 64 bytes with 0 to avoid garbage in RAM
    dec rcx             ; Discount the null byte we already copied
    jz .send
    xor al, al
    rep stosb

.send:
    ; --- 4. Send packet ---
    call net_create_udp
    mov [fd_sock], rax

    mov rdi, rax        ; fd
    mov rsi, tx_buffer  ; buffer (80 bytes)
    mov rdx, 80         ; length
    mov rcx, addr_core  ; destination
    call net_send_udp

.exit_ok:
    mov rax, 60
    xor rdi, rdi
    syscall

.exit_error:
    mov rax, 60
    mov rdi, 1
    syscall