section .data
    fb_device db "/dev/fb0", 0

section .bss
    fd resq 1
    var_info resb 160  ; Reserve enough space for fb_var_screeninfo
    fix_info resb 80   ; Reserve enough space for fb_fix_screeninfo
    fb_ptr resq 1

section .text
    global _start

_start:
    ; Open framebuffer
    mov rax, 2
    lea rdi, [fb_device]
    mov rsi, 2          ; O_RDWR
    syscall
    cmp rax, 0
    jl error
    mov [fd], rax

    ; Get variable screen info (FBIOGET_VSCREENINFO)
    mov rax, 16         ; sys_ioctl
    mov rdi, [fd]
    mov rsi, 0x4600     ; FBIOGET_VSCREENINFO
    lea rdx, [var_info]
    syscall
    test rax, rax
    jnz error

    ; Get fixed screen info (FBIOGET_FSCREENINFO)
    mov rax, 16         ; sys_ioctl
    mov rdi, [fd]
    mov rsi, 0x4602     ; FBIOGET_FSCREENINFO
    lea rdx, [fix_info]
    syscall
    test rax, rax
    jnz error

    ; Map framebuffer
    mov rax, 9          ; sys_mmap
    xor rdi, rdi
    mov rsi, [fix_info + 8]  ; smem_len (offset 8)
    mov rdx, 3          ; PROT_READ | PROT_WRITE
    mov r10, 1          ; MAP_SHARED
    mov r8, [fd]
    xor r9, r9
    syscall
    cmp rax, -1
    je error
    mov [fb_ptr], rax

    ; Draw pixel at (100, 100)
    ; Calculate offset: (y * line_length) + (x * (bpp/8))
    mov eax, 100        ; y = 100
    mov ebx, [fix_info + 16]  ; line_length (offset 16)
    mul ebx             ; y * line_length
    mov ebx, 100        ; x = 100
    mov ecx, [var_info + 24]  ; bits_per_pixel (offset 24)
    shr ecx, 3          ; bytes_per_pixel = bpp / 8
    imul ebx, ecx       ; x * bytes_per_pixel
    add eax, ebx        ; total offset
    mov rdi, [fb_ptr]
    add rdi, rax
    mov dword [rdi], 0xFFFF0000  ; Red (ARGB)

    ; Cleanup
    mov rax, 11         ; sys_munmap
    mov rdi, [fb_ptr]
    mov rsi, [fix_info + 8]
    syscall

    mov rax, 3          ; sys_close
    mov rdi, [fd]
    syscall

    mov rax, 60         ; sys_exit
    xor rdi, rdi
    syscall

error:
    ; Exit with code 1 on error
    mov rax, 60
    mov rdi, 1
    syscall