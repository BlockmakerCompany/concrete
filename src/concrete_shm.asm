; src/concrete_shm.asm - Shared Memory Module (Zero-Copy)
; Exposes the function to initialize and map the memory segment.

%include "concrete.inc"

section .text
    global shm_init

; -----------------------------------------------------------------------------
; shm_init
; Creates, truncates, and maps a shared memory file.
; Arguments:
;   rdi = Pointer to the path string (e.g., "/dev/shm/concrete.data")
;   rsi = Size in bytes (e.g., 4096)
; Returns:
;   rax = Pointer to mapped memory, or negative error code
; -----------------------------------------------------------------------------
shm_init:
    ; Prologue: Save non-volatile registers we will use
    push rbx
    push r12
    push r13

    mov r12, rdi            ; r12 = file path
    mov r13, rsi            ; r13 = desired size

    ; --- 1. Open/Create SHM ---
    mov rax, SYS_OPEN       ; syscall 2
    mov rdi, r12            ; path
    mov rsi, 66             ; O_CREAT | O_RDWR
    mov rdx, 0666o          ; Permissions rw-rw-rw-
    syscall
    test rax, rax
    js .error               ; If negative, jump to error
    mov rbx, rax            ; rbx = SHM File Descriptor

    ; --- 2. Truncate to exact size ---
    mov rax, SYS_FTRUNCATE  ; syscall 77
    mov rdi, rbx            ; fd
    mov rsi, r13            ; size
    syscall
    test rax, rax
    js .error_close

    ; --- 3. Mmap (Map into RAM) ---
    mov rax, SYS_MMAP       ; syscall 9
    xor rdi, rdi            ; addr = 0 (kernel decides)
    mov rsi, r13            ; size
    mov rdx, 3              ; PROT_READ | PROT_WRITE
    mov r10, 1              ; MAP_SHARED
    mov r8, rbx             ; fd
    xor r9, r9              ; offset = 0
    syscall
    test rax, rax
    js .error_close

    ; Success: rax already contains the memory pointer.
    ; We no longer need the File Descriptor (rbx) open for mmap to work,
    ; but it is useful in some designs. For cleanliness, we will close it.
    push rax                ; Save the mmap pointer
    mov rax, SYS_CLOSE      ; syscall 3
    mov rdi, rbx
    syscall
    pop rax                 ; Restore the memory pointer to return it

    jmp .done

.error_close:
    ; If truncate or mmap failed, try to close the FD before exiting
    push rax                ; Save the original error
    mov rax, SYS_CLOSE
    mov rdi, rbx
    syscall
    pop rax                 ; Restore the original error

.error:
    ; rax already contains the negative error code
.done:
    ; Epilogue
    pop r13
    pop r12
    pop rbx
    ret