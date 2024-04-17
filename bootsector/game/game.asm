[bits 16]
[org 0x7c00]

start:
   
    mov ax, 0x00    ; Init segments
    mov ds, ax
    mov ax, 0xa000
    mov es, ax
    mov ax, 13h     ; Init VGA 
    int 10h

    ; Init game
    call draw_sky
    call draw_level

game_loop:
    call erease_player
    
    mov ax, 320             ; Screen width
    mul word [player_y]     ; y-coordinate
    add ax, 320*9           ; Bottom of the sprite
    add ax, [player_x]      ; Add x-coordinate
    cmp byte [mirror_direction], 0  ; Check direction
    jne shift_col_check
    dec ax                  
    jmp after_shift                  
    shift_col_check:
    add ax, 5
    after_shift:
    mov di, ax              ; Store in DI for ES:DI addressing
    
    mov ah, es:[di]         ; Check if platform
    cmp ah, SKY_COLOR
    jne run
    inc word [player_y]
    jmp fall

    ; Physics
    ; cmp word [player_y], GROUND_POS    ; Hard ground TODO: check if on platform
    ; jnb run                             ; Yes, can run
    ; add word [player_y], 5              ; No, falling 5px
    ; jmp fall

    run:
        call handle_keyboard
        cmp byte [mirror_direction], 0
        je run_right
    run_left:
        cmp word [player_x], 0
        je swap_direction
        dec word [player_x]
        jmp fall
    run_right:
        cmp word [player_x], 316
        je swap_direction
        inc word [player_x]
        jmp fall
    swap_direction:
        xor byte [mirror_direction], 1  ; swap direction
    fall:
        
    call draw_player
    call delay
   
jmp game_loop

delay:
    mov al, 0
    mov cx, 1
    mov dx, DELAY_MS
    mov ah, 86h
    int 15h
    ret


draw_sky:
    xor di,di
    mov al, SKY_COLOR
    mov cx, 320*170
    rep stosb

    ; mov al, GROUND_COLOR
    ; mov cx, 320*20
    ; rep stosb

    mov cx, 6
    draw_gradient:
    mov bx, GROUND_COLOR    ; Sky starting color
    next_color:
        push cx                  ; Save outer loop counter
        mov cx, 5
        mov dx, 320
        mov al, bl
    draw_grad_line:
        push cx                  ; Save inner loop counter
        mov cx, dx               ; Set CX to 320 for rep stosb
        rep stosb
        pop cx
        loop draw_grad_line
        pop cx 
        dec bx
        loop next_color
    ret 

erease_player:
    mov ax, 320            ; Screen width
    mul word [player_y]    ; y-coordinate
    add ax, [player_x]     ; Add x-coordinate
    mov di, ax             ; Store in DI for ES:DI addressing
    
    mov cx, 8           ; Erease height 
    cmp byte [mirror_direction], 0
    je erease_line
    add di, 2
    erease_line:
        push cx             ; Save loop counter
        mov cx, 4           ; Erease width
        mov al, SKY_COLOR   ; Erease color
        rep stosb           ; Draw line
        add di, 316         ; 320-width
        pop cx          ; Restore loop counter
        loop erease_line
    ret

draw_player:
    mov bx, [current_frame]  ; Load current frame number

    mov ax, 32             ; Frame offset
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
        inc byte [current_frame]
        cmp byte [current_frame], 3
        jl skip_reset
        mov byte [current_frame], 0
    skip_reset:
    ret

handle_keyboard:
    mov ah, 0x01            ; Check if a key has been pressed
    int 0x16
    jz no_kb                ; Jump if no key is in the keyboard buffer
    mov ah, 0x00            ; Get the key press
    int 0x16
    xor byte [mirror_direction], 1  ; swap direction
no_kb:
    ret

draw_level:
    lea si, [level_data] ; Point SI to the start of level data
read_segment:
    lodsb               ; Load the next color into AL
    test al, al
    jz done             ; If color is 0, end of data
    mov bh, al          ; Save the color in BH
    lodsw               ; Load the start position into AX
    mov di, ax          ; DI now holds the start position
    lodsw               ; Load the length into AX
    ; mov cx, ax          ; Move length to CX for stosb
    
    mov cx, 4           ; Platform height  
    draw_platform:
        push cx         ; Save loop counter
        push ax         ; Save length
        mov cx, ax     
        mov al, bh
        add bh, 50
        rep stosb       ; Draw line
        
        pop ax        
        add di, 320
        sub di, ax      ; Move line down

        pop cx          ; Restore loop counter
        loop draw_platform

    jmp read_segment   ; Process next segment
done:
    ret                 ; Return from draw_level


.data:
player_x dw 160
player_y dw 8
current_frame dw 0
mirror_direction db 0
SKY_COLOR equ 102
GROUND_COLOR equ 187
GROUND_POS equ 160
DELAY_MS equ 1600

sprite_data:
    ; Dude - Frame 1
    db SKY_COLOR, SKY_COLOR, SKY_COLOR, SKY_COLOR
    db SKY_COLOR, 0x2A, 0x2B, SKY_COLOR
    db 0x2A, 0x5A, 0x0F, SKY_COLOR
    db SKY_COLOR, 0x42, SKY_COLOR, SKY_COLOR
    db SKY_COLOR, 0x34, 0x35, SKY_COLOR
    db SKY_COLOR, 0x35, 0x34, SKY_COLOR
    db SKY_COLOR, 0x36, 0x36, SKY_COLOR
    db 0x36, SKY_COLOR, 0x37, SKY_COLOR
    ; Dude - Frame 2
    db SKY_COLOR, SKY_COLOR, SKY_COLOR, SKY_COLOR
    db SKY_COLOR, 0x2A, 0x2B, SKY_COLOR
    db 0x2A, 0x5A, 0x0F, SKY_COLOR
    db SKY_COLOR, 0x42, SKY_COLOR, SKY_COLOR
    db SKY_COLOR, 0x34, 0x35, SKY_COLOR
    db SKY_COLOR, 0x34, 0x35, SKY_COLOR
    db SKY_COLOR, 0x36, 0x36, SKY_COLOR
    db SKY_COLOR, 0x36, 0x37, SKY_COLOR
    ; Dude - Frame 4
    db SKY_COLOR, 0x2A, 0x2B, SKY_COLOR
    db 0x2A, 0x5A, 0x0F, SKY_COLOR
    db SKY_COLOR, 0x42, SKY_COLOR, SKY_COLOR
    db SKY_COLOR, 0x34, 0x35, SKY_COLOR
    db 0x34, 0x35, 0x35, SKY_COLOR
    db SKY_COLOR, 0x36, 0x36, SKY_COLOR
    db SKY_COLOR, 0x36, 0x37, 0x37
    db SKY_COLOR, 0x36, SKY_COLOR, SKY_COLOR
    ; Level building sprites


level_data: ;Structure: color, position in buffer, length of the platform
    db 0x46
    dw 320*168
    dw 320
    db 0x46
    dw 320*10+10
    dw 50 
    db 0x46
    dw 320*50+140
    dw 75
    db 0x34
    dw 320*120
    dw 75
    db 0x3b
    dw 320*140+100
    dw 120
    db 0x3b
    dw 320*27+120
    dw 60
    db 0 ; End marker


; make boodsector
times 510 - ($ - $$) db 0  ; Pad remaining bytes to make 510 bytes
dw 0xAA55                  ; Boot signature at the end of 512 bytes

; make floppy
; times 1474560 - ($ - $$) db 0