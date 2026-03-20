; src/concrete_sync.asm - Synchronization Logic with Magic Header and Log
%include "concrete.inc"

; Network and logging procedures
extern net_recv_udp
extern net_send_udp
extern _log_info
extern _log_debug

; Global variables (defined in main/env)
extern shm_ptr, fd_local, fd_remote
extern rx_buffer, tx_buffer, addr_dest
extern msg_local, msg_remote

section .data
    ; 8-byte signature to identify legitimate Concrete packets
    magic_header db "CONCRETE"

section .text
    global sync_handle_local
    global sync_handle_remote

; -----------------------------------------------------------------------------
; sync_handle_local: Processes local RAM changes and broadcasts them to the cluster
; -----------------------------------------------------------------------------
sync_handle_local:
    ; 1. Clear the local activation socket
    mov rdi, [fd_local]
    mov rsi, rx_buffer
    mov rdx, 1024
    call net_recv_udp

    ; 2. Read Dirty Bitmap
    mov r12, [shm_ptr]
    mov rbx, [r12 + OFFSET_DIRTY]
    test rbx, rbx
    jz .clear_and_exit

.scan_bitmap:
    bsf rcx, rbx            ; Find first bit set to 1 (Block ID)
    jz .clear_and_exit
    btr rbx, rcx            ; Clear bit for the next iteration
    push rbx

    ; 3. ASSEMBLE SECURE PACKET (80 bytes)
    ; Structure: [MAGIC(8)] + [BLOCK_ID(8)] + [DATA(64)]

    ; Copy Magic Header
    mov rax, [magic_header]
    mov [tx_buffer], rax

    ; Copy Block ID
    mov [tx_buffer + 8], rcx

    ; Copy Payload from SHM
    mov rax, rcx
    shl rax, 6                      ; ID * 64 (offset in SHM)
    mov rsi, r12
    add rsi, rax                    ; Source: SHM + Offset
    mov rdi, tx_buffer + 16         ; Destination: tx_buffer + 16 (after magic and ID)
    mov rcx, 64
    cld
    rep movsb

    ; 4. Send to the Cluster
    mov rdi, [fd_remote]
    mov rsi, tx_buffer
    mov rdx, 80                     ; Total size including Magic Header
    mov rcx, addr_dest
    call net_send_udp

    pop rbx
    test rbx, rbx
    jnz .scan_bitmap

.clear_and_exit:
    ; Reset the bitmap globally
    mov qword [r12 + OFFSET_DIRTY], 0
    mfence

    mov rsi, msg_local
    call _log_debug                 ; Only report in Debug mode
    ret

; -----------------------------------------------------------------------------
; sync_handle_remote: Receives, VALIDATES, and injects deltas from other nodes
; -----------------------------------------------------------------------------
sync_handle_remote:
    mov rdi, [fd_remote]
    mov rsi, rx_buffer
    mov rdx, 1024
    call net_recv_udp

    ; VALIDATION 1: Does it have the correct size (80 bytes)?
    cmp rax, 80
    jne .invalid

    ; VALIDATION 2: Does it contain the "CONCRETE" signature?
    mov rax, [magic_header]
    cmp [rx_buffer], rax
    jne .invalid

    ; 5. PROCESS ID AND DATA
    mov rcx, [rx_buffer + 8]        ; Get Block ID
    cmp rcx, 63                     ; Validate range (0-63)
    ja .invalid

    ; Calculate destination in our RAM
    shl rcx, 6                      ; ID * 64
    mov rdi, [shm_ptr]
    add rdi, rcx

    ; Copy Payload (located at offset +16 in rx_buffer)
    mov rsi, rx_buffer + 16
    mov rcx, 64
    cld
    rep movsb
    mfence

    mov rsi, msg_remote
    call _log_debug                 ; Only report in Debug mode
    ret

.invalid:
    ; Malformed packet or attack detected: ignore it silently
    ret