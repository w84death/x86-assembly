[ORG 0x7C00]  ; Set the origin to where the boot sector will be loaded.

; Clear the screen
mov ah, 0x00   ; Function: Set video mode
mov al, 0x03   ; Mode 03: 80x25 text mode
int 0x10       ; BIOS video interrupt

; Move cursor to the middle of the screen (column 40, row 12)
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

mov ah, 0x02   ; Function to set cursor position
mov bh, 0x00   ; Page number
mov dh, 18     ; Row number (0-based, so 12 is the 13th row)
mov dl, 39     ; Column number (0-based, so 39 is the 40th column)
int 0x10       ; BIOS video interrupt

; Infinite loop to halt the CPU after printing
jmp $

times 510 - ($ - $$) db 0  ; Pad remaining bytes to make 510 bytes
dw 0xAA55                  ; Boot signature at the end of 512 bytes
