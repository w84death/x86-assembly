; P1X BOOTLOADER V1.5
; FOR x86 CPU
;
; Description:
;   16-bit real mode bootloader for the floppy disk.
;   Loads needed sectors from the disk to the memory and jumps to the loaded code.
;
; Size category: 4096 bytes / 4KB
;
; Author: Krzysztof Krystian Jankowski
; Web: smol.p1x.in/assembly/#bootloader
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
    mov bh, 0x3f          ; Background color
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
    mov ax, 0x0210         ; 4KB = 16 sectors
    xor dx, dx             ; CH = 0 cylinder, DH = 0 head
    mov cl, 2              ; CL = start at second sector
    int 0x13               ; BIOS disk interrupt
    jc disk_error          ; Jump if carry flag set (error)

.display_wait_msg:
  mov si, done_msg
  call print_string

  .display_payload:
    mov dx, 0x0608
    call set_cursor
    mov bl, 0x1B
    call color_line
    mov si, game_title_msg
    call print_string

    add dh, 0x04
    call set_cursor
    mov si, game_line1_msg
    call print_string
    add dh, 0x2
    call set_cursor
    mov si, game_line2_msg
    call print_string

    add dh, 0x8
    call set_cursor

    mov bl, 0x30
    call color_line
    
    mov si, game_info_msg
    call print_string

    add dh, 0x2
    call set_cursor

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

color_line:
  mov ah, 0x09
  mov cx, 64
  int 0x10
ret

print_string:
  mov ah, 0x0e            ; BIOS teletype output function
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

title_msg db    'P1X Bootloader V1.5',0x0A,0x0D,0x0
loading_msg db  'Loading... ',0x0
error_msg db    'Err',0x0
done_msg db     'OK!',0x0
wait_msg db     'Press any key...',0x0
game_title_msg db 'WELCOME TO THE 12-TH ASSEMBLY GAME  BY P1X, JAN 2025',0x0
game_line1_msg db 'Experimental game to test new, fast engine. Runs on 386SX!',0x0
game_line2_msg db 'Coded & designed by Krzysztof Krystian Jankowski',0x0
game_info_msg db 'Visit http://smol.p1x.in/assembly/ for more games!',0x0

times 507 - ($ - $$) db 0   ; Pad to 510 bytes
db "P1X"                    ; Use HEX viewer to see P1X at the end of binary
dw 0xAA55                   ; Boot signature
