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

.clear_screen:
    mov ah, 0x06           ; BIOS scroll up function
    mov al, 0              ; Clear entire screen
    mov bh, 0xf0           ; Text attribute
    mov cx, 0              ; Upper left corner
    mov dx, 0x184F         ; Lower right corner
    int 0x10               ; BIOS video interrupt

.display_title:
    mov dh, 5               ; Row
    mov dl, 29              ; Column
    call set_cursor
    mov si, welcome_msg
    call print_string

.load_code:
    mov dh, 10               ; Row
    mov dl, 4              ; Column
    call set_cursor
    mov si, loading_msg
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

.display_wait_msg:
    mov si, done_msg
    call print_string

    mov dh, 12               ; Row
    mov dl, 4              ; Column
    call set_cursor
    mov si, wait_msg
    call print_string
    
    xor ax, ax
    int 0x16               ; BIOS keyboard interrupt (wait for keypress)

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

set_cursor:
    mov ah, 0x02            ; BIOS set cursor position function
    mov bh, 0               ; Page number
    int 0x10                ; BIOS video interrupt
    ret

welcome_msg db '>>> P1X Bootloader <<<', 0
loading_msg db 'Loading... ', 0
done_msg db 'Done!', 0
wait_msg db 'Press any key to start...', 0
error_msg db 'Disk Read Error!', 0
boot_drive db 0             ; Variable to store boot drive number

times 507 - ($ - $$) db 0   ; Pad to 510 bytes
db "P1X"                    ; Use HEX viewer to see P1X at the end of binary
dw 0xAA55                   ; Boot signature
