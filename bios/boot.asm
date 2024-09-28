; BOOTLOADER
; BIOS
;
; Description:
;   16-bit real mode bootloader for the floppy disk.
;   Loads 4 sectors from the disk to the memory and jumps to the loaded code.
;
; Size category: 512 bytes
;
; Author: Krzysztof Krystian Jankowski
; Web: smol.p1x.in/assembly/#dinopix
; License: MIT

; TODO: add flag for bg color attribute for different floppies colors

org 0x7C00
use16 

start:
    cli                 ; Disable interrupts
    xor ax, ax
    mov ds, ax
    mov es, ax

.clear_screen:
    mov ah, 0x06          ; Clear entire screen
    mov bh, 0x70          ; Background color
    mov dx, 0x184F        ; Lower right corner
    int 0x10

    xor dx, dx
    mov ah, 0x2
    mov bh, 0x0
    int 0x10

.load_code:

    mov si, title_msg
    call print_string

    mov si, loading_msg
    call print_string

    mov ax, 0x7E0          ; Segment where code will be loaded
    mov es, ax
    mov bx, 0x0100         ; Offset where code will be loaded

.load_sectors:
    mov ax, 0x0204         ; 4 sectors to load from the disk
    xor dx, dx             ; CH = 0 cylinder, DH = 0 head
    mov cl, 2              ; CL = start at second sector
    int 0x13               ; BIOS disk interrupt
    jc disk_error          ; Jump if carry flag set (error)

.display_wait_msg:
    mov si, done_msg
    call print_string

    .display_payload:
        mov si, payload_msg
        call print_string

    mov si, wait_msg
    call print_string
    
    xor ax, ax
    int 0x16               ; BIOS keyboard interrupt (wait for keypress)

    mov ax, 0x7E0          ; Segment where code is loaded
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00         ; Initialize stack pointer  

    jmp 0x7E0:0x0100        ; Jump to the loaded code; run the game!

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

title_msg db    'P1X Bootloader V1.3',0x0A,0x0D,0x0
loading_msg db  'Loading... ',0x0
error_msg db    'Err',0x0
done_msg db     'OK!',0x0A,0x0A,0x0A,0x0D,0x0
wait_msg db     'Press any key to start...',0x0
payload_msg:
db '*** MYSTERIES OF THE FORGOTTEN ISLES ***',0x0A,0x0D
db 0x0A
db 'Explore the islands. Find all gold and bring it to the chest.',0x0A,0x0D
db 'Use rocks to build bridges on shallow water. Avoid wildlife.',0x0A,0x0D
db 0x0A
db 'Use Arrows to move, Spacebar to drop items, Escape to reset.',0x0A,0x0D
db 0x0A
db 0x0

times 507 - ($ - $$) db 0   ; Pad to 510 bytes
db "P1X"                    ; Use HEX viewer to see P1X at the end of binary
dw 0xAA55                   ; Boot signature
