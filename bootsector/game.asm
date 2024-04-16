org 0x7c00

start:
    mov ax, 0x00
    mov ds, ax
    mov ax, 0xa000
    mov es, ax

    mov ax, 0x0013  ; VGA
    int 0x10

    ; draw background

    mov al, 0x66    ; sky
    mov cx, 320*180
    xor di,di
    rep stosb

    mov bx, 180    ; y position
    mov ax, 320    ; screen width
    mul bx         ; memory position (y*width)
    mov di, ax     ; destination index in video memory
    mov cx, 320    ; number of pixels in one line
    
    mov al, 0xa   ; grass
    rep stosb

    mov al, 0x76    ; ground
    mov cx, 320*20
    rep stosb

demoloop:
    ; clear screen - TODO: clear only behind player
    mov al, 0x66
    mov cx, 320*10
    add cx, 320*170 ; clear 170-180 lines
    xor di,di
    rep stosb

    call draw_player
    call draw_all_coins
    call handle_keyboard

jmp demoloop


draw_player:

    mov bx, [current_frame]  ; Load current frame number

    mov ax, 32             ; Calculate frame offset (each frame is 32 bytes in the sprite data)
    mul bx                 ; AX = 32 * current frame number
    mov si, sprite_data
    add si, ax             ; SI points to the start of the current frame data

    ; Calculate the starting address in video memory
    mov ax, 320            ; Screen width
    mul word [player_y]    ; y-coordinate
    add ax, [player_x]     ; Add x-coordinate
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
        cmp word [current_frame], 3
        jl skip_reset
        mov word [current_frame], 0
    skip_reset:
    ret

draw_coin:
    mov ax, 32*3             ; Calculate frame offset (data is after 4th frame)
    mov si, sprite_data
    add si, ax             ; SI points to the start of the current frame data

    mov ax, 320            ; Screen width
    mul word [coin_y]      ; y-coordinate
    add ax, [coin_x]       ; Add x-coordinate
    mov di, ax             ; Store in DI for ES:DI addressing
    mov cx, 4              ; 3 rows
    draw_coin_row:
        push cx
        mov cx, 3           ; 4 pixels per row
        rep movsb           ; Move sprite row to video memory
        pop cx
        add di, 317         ; Move DI to the start of the next line (320 - 4)
        loop draw_coin_row
    ret


draw_all_coins:
    mov bx, 0                ; Index for coin_positions
    mov cx, [num_coins]      ; Load the number of coins

draw_next_coin:

    ; Skip this coin if it has been collected
    cmp byte [coin_collected + bx], 1
    je skip_coin

    ; Load position from coin_positions array
    mov ax, [coin_positions + bx]      ; Load x
    mov [coin_x], ax
    mov ax, 174  ; Load y
    mov [coin_y], ax

    ; check collision
    mov ax, [player_x]
    add ax, 4                           ; ax = player_x + player_width
    cmp ax, [coin_x]
    jle no_overlap                      ; No overlap if player_x + width <= coin_x

    mov ax, [coin_x]
    add ax, 3                           ; ax = coin_x + coin_width
    cmp ax, [player_x]
    jle no_overlap                      ; No overlap if coin_x + width <= player_x

    ; flag coin as collected
    mov byte [coin_collected + bx], 1
    jmp skip_coin

    no_overlap:
        push cx
        push bx
        call draw_coin           ; Call the draw function
        pop bx
        pop cx

    skip_coin:

    add bx, 2                ; Move to the next coin position (each position is 2 bytes)
    loop draw_next_coin      ; Decrement CX and loop if CX != 0
    ret


handle_keyboard:
        ; Check if a key has been pressed
        mov ah, 0x01
        int 0x16
        jz handle_keyboard  ; Jump if no key is in the keyboard buffer

        mov ah, 0x00         ; Get the key press
        int 0x16
        cmp ah, 0x4B       ; Compare with scan code for left arrow
        je move_left
        cmp ah, 0x4D       ; Compare with scan code for right arrow
        je move_right
        jmp handle_keyboard ; Unknown button, loop back

    move_left:
        dec word [player_x]
        mov word [mirror_direction], 1
        ret

    move_right:
        inc word [player_x]
        mov word [mirror_direction], 0
        ret

.data:
player_x dw 50
player_y dw 172
current_frame dw 0
mirror_direction dw 0
coin_x dw 0
coin_y dw 0
coin_positions dw 10, 30, 70, 90, 120, 140, 200, 210, 240
coin_collected dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
num_coins dw 7

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
    db 0x66, 0x2c, 0x66
    db 0x2c, 0x0f, 0x2b
    db 0x2c, 0x0f, 0x2b
    db 0x66, 0x2b, 0x66  

; make boodsector
times 510 - ($ - $$) db 0  ; Pad remaining bytes to make 510 bytes
dw 0xAA55                  ; Boot signature at the end of 512 bytes

; make floppy
; times 1474560 - ($ - $$) db 0