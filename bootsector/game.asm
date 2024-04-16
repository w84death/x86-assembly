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

; DEMO



start:
    mov ax, 0x00
    mov ds, ax
    mov ax, 0xa000
    mov es, ax

    mov ax, 0x0013  ; VGA
    int 0x10


    ; top-bottom frame lines
    mov al, 3

    mov di, 0x0
    mov cx, 320
    repe stosb

    mov di, 320*199
    mov cx, 320
    repe stosb

demoloop:

    draw:

    ; clear screen
    mov di, 320
    mov cx, 320*198  
    mov al, 0
    rep stosb

    ; Assume sprite_x and sprite_y contain the coordinates where the sprite should be drawn
    ; ES must be set to the video segment, which is 0xA000 for mode 13h
    ; mov ax, 0xA000
    ; mov es, ax

    mov bx, [current_frame]  ; Load current frame number

    mov ax, 32             ; Calculate frame offset (each frame is 32 bytes in the sprite data)
    mul bx                 ; AX = 32 * current frame number
    mov si, sprite_data
    add si, ax             ; SI points to the start of the current frame data

    ; Calculate the starting address in video memory
    mov ax, 320            ; Screen width
    mul word [sprite_y]    ; y-coordinate
    add ax, [sprite_x]     ; Add x-coordinate
    mov di, ax             ; Store in DI for ES:DI addressing
   
   ; Check mirror direction
    cmp byte [mirror_direction], 0
    je draw_normal

    ; Draw mirrored sprite
    mov cx, 8          ; 8 rows

        add di, 4           ; shift sprite to the right
    draw_mirrored_row:
        push cx
        mov cx, 4           ; 4 pixels per row
        lea bx, [si+3]      ; Start from the end of the row in sprite data
        push di             ; Save DI before drawing each row
        mirror_pixel_loop:
            lodsb           ; Load byte from SI into AL, decrementing SI
            stosb           ; Store byte from AL into DI, incrementing DI
            add di, -2      ; Move DI back two places (to correct the forward increment from stosb)
        loop mirror_pixel_loop
        pop di              ; Restore DI from the saved value before drawing each row
        add di, 320         ; Move DI to the start of the next line
        pop cx
        loop draw_mirrored_row
        jmp finish_draw

    draw_normal:
    ; Draw the sprite frame normally
    mov cx, 8              ; 8 rows
    draw_sprite_row:
        push cx
        mov cx, 4           ; 4 pixels per row
        rep movsb           ; Move sprite row to video memory
        pop cx
        add di, 316         ; Move DI to the start of the next line (320 - 4)
        loop draw_sprite_row

    finish_draw:
        inc word [current_frame]
        cmp word [current_frame], 4
        jl skip_reset
        mov word [current_frame], 0
    skip_reset:

    check_key_press:
        ; Check if a key has been pressed
        mov ah, 0x01
        int 0x16
        jz check_key_press  ; Jump if no key is in the keyboard buffer

        ; Get the key press
        mov ah, 0x00
        int 0x16
        cmp ah, 0x4B       ; Compare with scan code for left arrow
        je move_left
        cmp ah, 0x4D       ; Compare with scan code for right arrow
        je move_right
        cmp ah, 0x48   ; Up Arrow scan code
        je move_up
        cmp ah, 0x50   ; Down Arrow scan code
        je move_down
        jmp check_key_press

    move_left:
        dec word [sprite_x]
        mov word [mirror_direction], 1
        jmp draw

    move_right:
        inc word [sprite_x]
        mov word [mirror_direction], 0
        jmp draw

    move_up:
        dec word [sprite_y]
        jmp draw

    move_down:
        inc word [sprite_y]
        jmp draw

jmp demoloop

; END DEMO

.data:
sprite_x dw 150
sprite_y dw 180
current_frame dw 0
mirror_direction dw 0

sprite_data:
    ; Frame 1
    db 0x00, 0x00, 0x00, 0x00
    db 0x00, 0x2A, 0x2B, 0x00
    db 0x2A, 0x5A, 0x0F, 0x00
    db 0x00, 0x42, 0x00, 0x00
    db 0x00, 0x34, 0x35, 0x00
    db 0x00, 0x34, 0x35, 0x00
    db 0x00, 0x36, 0x36, 0x00
    db 0x36, 0x00, 0x37, 0x00
    ; Frame 2
    db 0x00, 0x2A, 0x2B, 0x00
    db 0x2A, 0x5A, 0x0F, 0x00
    db 0x00, 0x42, 0x00, 0x00
    db 0x00, 0x34, 0x35, 0x00
    db 0x00, 0x34, 0x35, 0x00
    db 0x00, 0x36, 0x36, 0x00
    db 0x00, 0x36, 0x37, 0x37
    db 0x00, 0x36, 0x00, 0x00
     ; Frame 3
    db 0x00, 0x2A, 0x2B, 0x00
    db 0x2A, 0x5A, 0x0F, 0x00
    db 0x00, 0x42, 0x00, 0x00
    db 0x00, 0x34, 0x35, 0x00
    db 0x00, 0x34, 0x35, 0x00
    db 0x00, 0x36, 0x36, 0x00
    db 0x00, 0x36, 0x37, 0x00
    db 0x00, 0x36, 0x00, 0x37
    ; Frame 4
    db 0x00, 0x00, 0x00, 0x00
    db 0x2A, 0x2A, 0x2B, 0x00
    db 0x00, 0x5A, 0x0F, 0x00
    db 0x00, 0x42, 0x00, 0x00
    db 0x00, 0x34, 0x35, 0x00
    db 0x00, 0x34, 0x35, 0x00
    db 0x00, 0x36, 0x36, 0x00
    db 0x00, 0x36, 0x37, 0x00
; make boodsector
times 510 - ($ - $$) db 0  ; Pad remaining bytes to make 510 bytes
dw 0xAA55                  ; Boot signature at the end of 512 bytes

; make floppy
; times 1474560 - ($ - $$) db 0