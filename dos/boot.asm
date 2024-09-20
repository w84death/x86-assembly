; BOOTLOADER
; BIOS
;
; Description:
;   16-bit real mode bootloader for the floppy disk.
;
; Size category: 512 bytes
;
; Author: Krzysztof Krystian Jankowski
; Web: smol.p1x.in/assembly/#dinopix
; License: MIT

org 0x7C00
use16 

start:
    cli                 ; Disable interrupts
    xor ax, ax
    mov ds, ax
    mov es, ax

    mov [boot_drive], dl   ; Save the boot drive number

    ; Display 'Loading...' message
    mov si, msg
    call print_string

    ; Set up ES:BX to point to 0x7E0:0x0100
    mov ax, 0x7E0          ; ES = 0x7E0
    mov es, ax
    mov bx, 0x0100         ; BX = 0x0100

    ; Load next 4 sectors into ES:BX
    mov ah, 0x02           ; BIOS read sectors function
    mov al, 4              ; Number of sectors to read
    mov ch, 0              ; Cylinder 0
    mov dh, 0              ; Head 0
    mov cl, 2              ; Sector 2 (sectors start at 1)
    mov dl, [boot_drive]   ; Boot drive number
    int 0x13               ; BIOS disk interrupt
    jc disk_error          ; Jump if carry flag set (error)

    ; Set up segment registers for the loaded code
    mov ax, 0x7E0          ; Segment where code is loaded
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00         ; Initialize stack pointer

    ; Jump to the loaded code at 0x7E0:0x0100
    jmp 0x7E0:0x0100

disk_error:
    mov si, error_msg
    call print_string
    hlt                     ; Halt the system

print_string:
    mov ah, 0x0E            ; BIOS teletype output function
.next_char:
    lodsb                   ; Load next character from SI into AL
    cmp al, 0
    je .done
    int 0x10                ; BIOS video interrupt
    jmp .next_char
.done:
    ret

msg db 'Loading...', 0
error_msg db 'Disk Read Error!', 0
boot_drive db 0            ; Variable to store boot drive number

times 507 - ($ - $$) db 0  ; Pad to 510 bytes
db "P1X"    ; Use HEX viewer to see P1X at the end of binary
dw 0xAA55                  ; Boot signature
