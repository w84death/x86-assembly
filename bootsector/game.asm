org 0x7c00

; Clear the screen
mov ah, 0x00   ; Function: Set video mode
mov al, 0x03   ; Mode 03: 80x25 text mode
int 0x10       ; BIOS video interrupt

; Initialize ES register for video segment
mov ax, 0xB800
mov es, ax

; Set page number to zero
mov bh, 0

; Set the character and attribute for filling
mov al, ' '         ; Character to fill the screen with (space)
mov bl, 1Eh         ; Attribute (blue background, yellow foreground)

mov dh, 0           ; Initial row
mov dl, 0           ; Initial column

fill_screen:
    ; Set cursor position for each new line
    mov ah, 02h     ; Function to set cursor position
    int 10h         ; BIOS video interrupt

    ; Write characters across the line
    mov ah, 09h     ; Function to write character and attribute
    mov cx, 80      ; Number of characters to write (full row)
    int 10h         ; BIOS video interrupt

    ; Move to the next line
    inc dh          ; Increment row number
    cmp dh, 25      ; Compare with total rows (standard text mode)
    jl fill_screen  ; Loop back if less than 25

; Define the string and its end label for looping
mov si, welcome_msg  ; Point SI to the start of the string
mov ah, 02h
mov dh, 12           ; Initial row
mov dl, 20           ; Initial column
int 10h

print_string:
    lodsb            ; Load the next byte from DS:SI into AL, SI++
    or al, al        ; Check if the character is zero (end of string)
    jz done          ; If zero, we're done
    mov ah, 0x09     ; Function 09h - Write Character and Attribute
    mov bh, 0x00     ; Page number
    mov bl, 0x1E     ; Attribute (blue background, yellow foreground)
    mov cx, 0x01     ; Write each character once
    int 0x10         ; Call BIOS video interrupt
    
    ; Move the cursor right
    mov ah, 0x03     ; Read current cursor position
    int 0x10         ; BX = page, DX = cursor position (DH = row, DL = column)
    inc dl           ; Increment column
    cmp dl, 80       ; Check if we reached the end of the row
    jne update_cursor
    xor dl, dl       ; Reset column to 0 for new line
    inc dh           ; Move to the next row

update_cursor:
    mov ah, 0x02     ; Function to set cursor position
    int 0x10         ; Update cursor position with new values in DH (row) and DL (column)

    jmp print_string ; Loop back to print the next character


done:

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

    ; background colors
    mov al, 0x66
    mov cx, 320*180
    xor di,di
    rep stosb

    mov al, 0x76
    mov cx, 320*180
    add cx, 320*20
    xor di,di
    rep stosb

    mov al, 0x02
    mov cx, 320*180
    add cx, 320
    xor di,di
    rep stosb

demoloop:

    draw:

    ; clear screen - TODO: clear only behind player
    mov al, 0x66
    mov cx, 320*180
    xor di,di
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
        ; cmp ah, 0x48   ; Up Arrow scan code
        ; je move_up
        ; cmp ah, 0x50   ; Down Arrow scan code
        ; je move_down
        jmp check_key_press

    move_left:
        dec word [sprite_x]
        mov word [mirror_direction], 1
        jmp draw

    move_right:
        inc word [sprite_x]
        mov word [mirror_direction], 0
        jmp draw

    ; move_up:
    ;     dec word [sprite_y]
    ;     jmp draw

    ; move_down:
    ;     inc word [sprite_y]
    ;     jmp draw

jmp demoloop

; END DEMO

.data:
welcome_msg db 'Welcome to the P1X boot sector game', 0
sprite_x dw 50
sprite_y dw 172
current_frame dw 0
mirror_direction dw 0

sprite_data:
    ; Dude - Frame 1
    db 0x66, 0x66, 0x66, 0x66
    db 0x66, 0x2A, 0x2B, 0x66
    db 0x2A, 0x5A, 0x0F, 0x66
    db 0x66, 0x42, 0x66, 0x66
    db 0x66, 0x34, 0x35, 0x66
    db 0x66, 0x34, 0x35, 0x66
    db 0x66, 0x36, 0x36, 0x66
    db 0x36, 0x66, 0x37, 0x66
    ; Dude - Frame 2
    db 0x66, 0x2A, 0x2B, 0x66
    db 0x2A, 0x5A, 0x0F, 0x66
    db 0x66, 0x42, 0x66, 0x66
    db 0x66, 0x34, 0x35, 0x66
    db 0x66, 0x34, 0x35, 0x66
    db 0x66, 0x36, 0x36, 0x66
    db 0x66, 0x36, 0x37, 0x37
    db 0x66, 0x36, 0x66, 0x66
    ; Dude - Frame 3
    db 0x66, 0x2A, 0x2B, 0x66
    db 0x2A, 0x5A, 0x0F, 0x66
    db 0x66, 0x42, 0x66, 0x66
    db 0x66, 0x34, 0x35, 0x66
    db 0x66, 0x34, 0x35, 0x66
    db 0x66, 0x36, 0x36, 0x66
    db 0x66, 0x36, 0x37, 0x66
    db 0x66, 0x36, 0x66, 0x37
    ; Dude - Frame 4
    db 0x66, 0x66, 0x66, 0x66
    db 0x2A, 0x2A, 0x2B, 0x66
    db 0x66, 0x5A, 0x0F, 0x66
    db 0x66, 0x42, 0x66, 0x66
    db 0x66, 0x34, 0x35, 0x66
    db 0x66, 0x34, 0x35, 0x66
    db 0x66, 0x36, 0x36, 0x66
    db 0x66, 0x36, 0x37, 0x66
    ; Coin tile
    db 0x66, 0x66, 0x2c, 0x66
    db 0x66, 0x2c, 0x0f, 0x2b
    db 0x66, 0x2c, 0x0f, 0x2b
    db 0x66, 0x66, 0x2b, 0x66  

; make boodsector
times 510 - ($ - $$) db 0  ; Pad remaining bytes to make 510 bytes
dw 0xAA55                  ; Boot signature at the end of 512 bytes

; make floppy
; times 1474560 - ($ - $$) db 0