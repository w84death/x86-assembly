org 0x7c00

; clear_text_mode = 0x00
; text_mode = 0x10
; vga_mode = 0x13
; set_cursor_pos = 0x02
; write_char = 0x0a

; Clear the screen
mov ah, 0x00   ; Function: Set video mode
mov al, 0x03   ; Mode 03: 80x25 text mode
int 0x10       ; BIOS video interrupt

; Move cursor to the middle of the screen
mov ah, 0x02   ; Function to set cursor position
mov bh, 0x00   ; Page number
mov dh, 12     ; Row number (0-based, so 12 is the 13th row)
mov dl, 38     ; Column number (0-based, so 39 is the 40th column)
int 0x10       ; BIOS video interrupt

; Display 'P'
mov ah, 0x0E   ; Teletype output function of the BIOS interrupt 10h
mov al, 'P'
int 0x10       ; BIOS interrupt

; Display '1'
mov al, '1'
int 0x10       ; BIOS interrupt

; Display 'X'
mov al, 'X'
int 0x10       ; BIOS interrupt

; move blinking cursor below
mov ah, 0x02   ; Function to set cursor position
mov bh, 0x00   ; Page number
mov dh, 18     ; Row number (0-based, so 12 is the 13th row)
mov dl, 39     ; Column number (0-based, so 39 is the 40th column)
int 0x10       ; BIOS video interrupt

; Wait for any key press
mov ah, 0x00
int 0x16       ; BIOS keyboard interrupt

; Set graphics mode 320x200 256 color
mov ax, 0x13
int 0x10

; Plot a pixel
mov ah, 0x0C
mov al, 15       ; Color
mov cx, 0       ; X coordinate
mov dx, 0       ; Y coordinate
int 0x10


plot_pixel:


    ; Calculate random X position (0-319)
    xor bx, bx     ; Clear bx
    mov cx, 320    ; Max X value
    div cx         ; AX / CX, result in AX, remainder in DX
    mov cx, dx     ; Use remainder as our random X coordinate

    ; Calculate random Y position (0-199)
    mov ax, dx     ; Use dx again
    xor dx, dx     ; Clear dx
    mov bx, 200    ; Max Y value
    div bx         ; AX / BX, result in AX, remainder in DX
    mov dx, dx     ; Use remainder as our random Y coordinate

    ; Generate random color (0-255)
    mov ax, dx     ; Use dx again
    and ax, 0xFF   ; Limit to 255
    mov al, al     ; Assign color to al

    mov ah, 0x0C
    ;mov al, 15         ; Color
    int 0x10

    mov ah, 0x01
    int 0x16       ; BIOS keyboard interrupt

    jmp plot_pixel   ; Repeat

; Infinite loop to halt the CPU after printing
jmp $

times 510 - ($ - $$) db 0  ; Pad remaining bytes to make 510 bytes
dw 0xAA55                  ; Boot signature at the end of 512 bytes
